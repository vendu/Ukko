/* fat12.c: FAT12 interface
 *
 * Copyright 2016 Vincent Damewood
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "fat12.h"
#include "memory.h"
#include "uio.h"
#include "x86asm.h"

#define AttrReadOnly  0x01
#define AttrHidden    0x02
#define AttrSystem    0x04
#define AttrVolume    0x08
#define AttrDirectory 0x10
#define AttrArchive   0x20

struct fat12BootBlock
{
	char skip[3];
	char OemId[8];
	uint16_t BytesPerSector;
	uint8_t SectorsPerCluster;
	uint16_t ReservedSectorCount;
	uint8_t FatCount;
	uint16_t RootEntryCount;
	uint16_t SectorCount16;
	uint8_t MediaDescriptor;
	uint16_t FatSize16;
	uint16_t SectorsPerTrack;
	uint16_t HeadCount;
	uint32_t HiddenSectors;
	uint32_t SectorCount32;
	uint8_t DriveNumber;
	uint8_t Reserved;
	uint8_t BootSignature;
	uint32_t VolumeId;
	char VolumeLabel[11];
	char FsType[8];
} __attribute__((__packed__));
typedef struct fat12BootBlock BootBlock;

struct fat12DirectoryEntry
{
	char     Name[11];
	uint8_t  Attr;
	uint8_t  NtRes;
	uint8_t  CrtTimeTenth;
	uint16_t CrtTime;
	uint16_t CrtDate;
	uint16_t AccessDate;
	uint16_t ClusterHi;
	uint16_t ModTime;
	uint16_t ModDate;
	uint16_t ClusterLo;
	uint32_t FileSize;

} __attribute__((__packed__));
typedef struct fat12DirectoryEntry DirectoryEntry;

struct FileSystem
{
	BootBlock      *BootBlock;
	DirectoryEntry *RootDirectory;
	uint8_t             *FileAllocationTable;
	drvStorageDevice    *Device;
};
typedef struct FileSystem FileSystem;

static int Match(const char *EntryName, const char *filename)
{
	int loc = 0;
	for (int i = 0; i < 11; i++)
	{
		switch(filename[loc])
		{
			case '\0':
			case '/':
				if (EntryName[i] != ' ')
					return 0;
				break;
			case '.':
				if(i < 8)
				{
					if (EntryName[i] != ' ')
						return 0;
				}

				if (i == 7)
					loc++;

				if (i >= 8)
					return 0;
				break;
			case '"':
			case '*':
			case '+':
			case ',':
			case ':':
			case ';':
			case '<':
			case '=':
			case '>':
			case '?':
			case '[':
			case '\\':
			case ']':
			case '|':
				return 0;
			default:
				if (EntryName[i] != filename[loc])
					return 0;
				loc++;

				if (i == 7 && filename[loc] == '.')
					loc++;
		}
	}
	return filename[loc] == '\0' || filename[loc] == '/';
}

static BootBlock *LoadBootBlock(drvStorageDevice *device)
{
	BootBlock *block = NULL;

	block = memAlloc(1 << device->SectorSize(device->Driver.State));
	if (block)
		device->ReadSectors(device->Driver.State, 0, 1, block);
	return block;
}

static DirectoryEntry *LoadRootDirectory(drvStorageDevice *device, BootBlock *block)
{
	int RootSector = block->ReservedSectorCount + block->FatSize16 * block->FatCount;

	uint32_t RootSize = sizeof(DirectoryEntry) * block->RootEntryCount;
	int RootSectorCount = RootSize >> device->SectorSize(device->Driver.State);

	DirectoryEntry *RootDir = memAlloc(RootSize);
	if (RootDir)
		device->ReadSectors(device->Driver.State, RootSector, RootSectorCount, RootDir);
	return RootDir;
}

static uint8_t *LoadFat(drvStorageDevice *device, BootBlock *block)
{
	uint8_t *rVal = NULL;
	int allocSize = block->FatSize16 * block->BytesPerSector;
	rVal = memAlloc(allocSize);
	if (rVal)
		device->ReadSectors(
				device->Driver.State,
				block->ReservedSectorCount,
				block->FatSize16,
				rVal);
	return rVal;
}

FileSystem *fat12Initialize(drvStorageDevice *device)
{
	FileSystem *rVal = memAlloc(sizeof(FileSystem));
	if (!rVal)
		return NULL;

	rVal->Device = device;
	rVal->BootBlock = LoadBootBlock(device);

	if (rVal->BootBlock)
	{
		rVal->RootDirectory = LoadRootDirectory(device, rVal->BootBlock);
		rVal->FileAllocationTable = LoadFat(device, rVal->BootBlock);
		rVal->FileAllocationTable = LoadFat(device, rVal->BootBlock);
	}

	if(!(rVal->BootBlock && rVal->RootDirectory))
	{
		memFree(rVal->BootBlock);
		memFree(rVal->RootDirectory);
		memFree(rVal->FileAllocationTable);
		rVal = NULL;
	}
	return rVal;
}

void fat12Delete(FileSystem *fs)
{
		memFree(fs->BootBlock);
		memFree(fs->RootDirectory);
		memFree(fs->FileAllocationTable);
		memFree(fs);
}

static uint32_t ClusterToSector(FileSystem *fs, uint16_t Cluster)
{
	return fs->BootBlock->ReservedSectorCount
		+ fs->BootBlock->FatCount * fs->BootBlock->FatSize16
		+ (fs->BootBlock->RootEntryCount * sizeof(DirectoryEntry))/fs->BootBlock->BytesPerSector
		+ fs->BootBlock->SectorsPerCluster*(Cluster-2);
}

static void *LoadFile(FileSystem *fs, DirectoryEntry *entry)
{
	uint32_t clusterSize = fs->BootBlock->BytesPerSector * fs->BootBlock->SectorsPerCluster;

	uint32_t allocSize = (entry->Attr & AttrDirectory) ? clusterSize : entry->FileSize;

	if (allocSize % clusterSize != 0)
	{
		allocSize /= clusterSize;
		allocSize++;
		allocSize *= clusterSize;
	}

	char *buffer = memAlloc(allocSize);

	uint16_t currentCluster = entry->ClusterLo;
	for (char *position = buffer; position < (buffer+allocSize); position += clusterSize)
	{
		fs->Device->ReadSectors(
			fs->Device->Driver.State,
			ClusterToSector(fs, currentCluster),
			fs->BootBlock->SectorsPerCluster,
			position);

		uint16_t fatEntry = currentCluster + (currentCluster >> 1);
		uint16_t nextCluster = 0;

		nextCluster =
			(fs->FileAllocationTable[fatEntry+1] << 8)
			| fs->FileAllocationTable[fatEntry];

		if (currentCluster % 2)
			nextCluster >>= 4; // Low-order bits are garbage
		else
			nextCluster &= 0xFFF; // High-order bits are garbage

		currentCluster = nextCluster;
	}


	return buffer;
}

static int IsRootDirectory(const char *file)
{
	while (*file == '/')
		file++;
	return *file == '\0';
}

static DirectoryEntry *SeekFile(FileSystem *fs, const char *file)
{
	DirectoryEntry *CurrentDirectory = fs->RootDirectory;
	DirectoryEntry *rVal             = NULL;
	const char *CurrentName = file;

	while (*CurrentName == '/')
		CurrentName++;

	while(*CurrentName)
	{
		DirectoryEntry *NextEntry = NULL;

		for(DirectoryEntry *entry = CurrentDirectory; entry->Name[0] != '\0'; entry++)
		{

			if (Match(entry->Name, CurrentName))
			{
				NextEntry = entry;
				break;
			}
		}

		if (!NextEntry)
			return NULL;

		while(*CurrentName != '/' && *CurrentName != '\0')
			CurrentName++;

		// If the NextEntry is not a directory but the path
		// uses it as such.
		if (*CurrentName == '/' && !(NextEntry->Attr & 0x10))
			return NULL;

		while (*CurrentName == '/')
			CurrentName++;

		if (*CurrentName != '\0')
		{
			DirectoryEntry *NextDirectory = LoadFile(fs, NextEntry);
			if (CurrentDirectory != fs->RootDirectory)
				memFree(CurrentDirectory);
			CurrentDirectory = NextDirectory;
		}
		else
		{
			rVal = memAlloc(sizeof(DirectoryEntry));
			rep_movsb(NextEntry, rVal, sizeof(DirectoryEntry));
			if (CurrentDirectory != fs->RootDirectory)
				memFree(CurrentDirectory);
		}
	}
	return rVal;
}

static void PrintEntry(DirectoryEntry *entry)
{
		uioPrintf("%.11s %2hhx %d\n", entry->Name, entry->Attr, entry->FileSize);
}

void fat12ShowDirectory(drvStorageDevice *device, const char *directory)
{
	FileSystem *fs = fat12Initialize(device);
	if (!fs)
	{
		uioPrint("Error loading file system.\n");
		return;
	}

	uioPrint("Directory: ");
	uioPrint(directory);
	uioPrintChar('\n');

	DirectoryEntry *BaseDir;
	if (IsRootDirectory(directory))
	{
		BaseDir = fs->RootDirectory;
	}
	else
	{
		DirectoryEntry *entry = SeekFile(fs, directory);
		if (entry->Attr & AttrDirectory)
		{
			BaseDir = LoadFile(fs, entry);
		}
		else
		{
			uioPrint("Not a directory.\n");
			return;
		}
	}

	for (DirectoryEntry *subEntry = BaseDir; subEntry->Name[0] != '\0'; subEntry++)
		PrintEntry(subEntry);


cleanup:
	if (BaseDir != fs->RootDirectory)
		memFree(BaseDir);

	fat12Delete(fs);
}

void fat12LoadFile(drvStorageDevice *device, const char *filename, void *destination)
{
	FileSystem *fs = fat12Initialize(device);
	if (!fs)
	{
		uioPrint("Error loading file system.\n");
		return;
	}

	DirectoryEntry *entry = SeekFile(fs, filename);

	void *Buffer = LoadFile(fs, entry);

	if (entry->Attr & AttrDirectory)
	{
		for (DirectoryEntry *subEntry = Buffer; subEntry->Name[0] != '\0'; subEntry++)
			PrintEntry(subEntry);
	}
	else
	{
		uioPrintN(entry->FileSize, Buffer);
	}
}


/* memory.c: Memory management
 *
 * Copyright 2015, 2016 Vincent Damewood
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

#include "uio.h"
#include "memory.h"

char *StatusTable[] =
{
	"",
	"1:Free",
	"2:Reserved",
	"3:ACPI Reclaimable",
	"4:ACPI Non-volatile",
	"5:Bad"
};

struct entry
{
	int base;
	int baseHi;
	int length;
	int lengthHi;
	int status;
	int extra;
};
typedef struct entry entry;

void memShowMap(void)
{
	uioPrint("Base     Size     Status\n");
	for (
			entry *i = (entry*)0x3308;
			i < (entry*)(0x3308 + sizeof(entry) * (*((int *)0x3300)));
			i++)
		uioPrintf("%.8X %.8x %s\n", i->base, i->length, StatusTable[i->status]);
}

#define PoolBase 0x30000
#define PoolSize 0x10000

void *freeSpace = (void*)PoolBase;

void *memAlloc(size_t size)
{
	char *tmp = freeSpace;
	if (tmp + size >= (char*)PoolBase + PoolSize)
		return NULL;

	freeSpace = tmp + size;
	return tmp;
}

void memFree(void *location)
{
}

void memReset(void)
{
	freeSpace = (void*)PoolBase;
}

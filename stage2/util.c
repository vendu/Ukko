/* util.c: Utility routines
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

#include "util.h"

int blStrCmp(const char *mem1, const char *mem2)
{
	int rVal;

	asm(
		"0:\n"
		"\tlodsb\n"
		"\tscasb\n"
		"\tjne 1f\n"
		"\tor %%al, %%al\n"
		"\tjnz 0b\n"
		"\txor %%eax, %%eax\n"
		"\tjmp 2f\n"
		"1:\n"
		"\tlahf\n"
		"\tmovsx %%ah, %%eax\n"
		"\tsar $6, %%eax\n"
		"\txor $1, %%eax\n"
		"2:\n"
		"\tnop"
		: "=a"(rVal)
		: "S"(mem1), "D"(mem2)
	);
        
	return rVal;
}

int blStrLen(const char *string)
{
	int i = 0;
	for (; *string++; i++);
	return i;
}

int blMemCmp(void *src, void *dst, int count)
{
	int rVal;
	asm(
	"repe cmpsb\n"
	"\tlahf\n"
	"\tmovsx %%ah, %%eax\n"
	"\tsar $6, %%eax\n"
	"\txor $1, %%eax"
	: "=a"(rVal)
	: "c"(count), "S"(src), "D"(dst)
	);
	return rVal;
}

/* uio.c: User interface input/output
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

#include "keyboard.h"
#include "screen.h"
#include "uio.h"

#define BufferSize 76
char Buffer[BufferSize];

const char *uioPrompt(const char *prompt)
{
	while (*prompt)
		scrPutGlyph(*prompt++);

	uint16_t eax;
	char *edi = Buffer;
	scrShowCursor();

	while (-1)
	{
		eax = KeyboardGetStroke();

		switch(eax &0xFF00)
		{
		case 0x0000:
			if (edi - Buffer == BufferSize-1)
				break;
			scrPutGlyph(eax);
			scrShowCursor();
			*edi++ = (char)(eax&0x00FF);
			break;
		case 0x0100:
			switch (eax & 0x00FF)
			{
			case 0x0000: // ESC
				while (edi > Buffer)
				{
					scrDelete();
					scrShowCursor();
					edi--;
				}
				break;
			case 0x0010: // Backspace
				if (edi != Buffer)
				{
					scrDelete();
					scrShowCursor();
					edi--;
				}
				break;
			case 0x0012: // Enter
				*edi = 0;
				scrBreakLine();
				return Buffer;
			}
		}
	}
}

void uioPrintChar(const char c)
{
	switch (c)
	{
	case '\n':
		scrBreakLine();
		break;
	case 0x7F:
		scrDelete();
		break;
	default:
		scrPutGlyph(c);
	}
}

void uioPrint(const char *string)
{
	for (const char *p = string; *p; p++)
		uioPrintChar(*p);
}

void uioPrintN(int length, const char *string)
{
	for (int i = 0; i < length; i++)
		uioPrintChar(string[i]);
}

// printf Support
#include <stdarg.h>

enum pfLength
{
	DEFAULT,
	HH,
	H,
	L,
	LL,
	BIGL
};

enum pfState
{
	END = 0,
	FLAGS,
	FIELD_WIDTH,
	DOT,
	PRECISION,
	LENGTH,
	CONVERSION
};

enum pfFlagAlign
{
	RIGHT = 0, // Align right, space pad
	ZPAD,      // Align right, zero pad
	LEFT       // Align left, space pad
};

enum pfFlagSign
{
	NONE = 0,    // Don't show a sign for non-negatives
	SPACE = ' ', // Space-pad sign for non-negatives
	PLUS = '+',  // Show + sign for non-negatives
};

static char *pfSignedDec(char *parseBuffer, long int value)
{
	parseBuffer[23] = 0;
	char *current = parseBuffer + 22;
	int runningValue = value;

	if (runningValue < 0)
		runningValue *= -1;

	do
	{
		int digit = runningValue % 10;
		runningValue /= 10;
		*current-- = '0' + digit;
	}
	while(runningValue);

	if (value < 0)
		*current-- = '-';

	return current+1;
}

static char *pfUnsigned(char *parseBuffer, unsigned long int value, int radix)
{
	parseBuffer[23] = 0;
	char *current = parseBuffer + 22;
	int runningValue = value;

	if (runningValue < 0)
		runningValue *= -1;

	do
	{
		int digit = runningValue % radix;
		runningValue /= radix;
		*current-- = digit + ((digit>9) ? ('A'-10) : '0');
	}
	while(runningValue);

	return current+1;
}

// This function is meant to work similarly to the C standard library
// printf function.
//
// uioPrintf doesn't support:
//   * '*' values for the field fidth and precision values
//   * the 'l' length on 'c' or 's' conversions.
//   * floating-point conversions (a, A, e, E, f,F, g, G)
//   * the n conversion
//   * multibyte strings
//
// Additionally uioPrintf doesn't return a value.
void uioPrintf(const char *format, ...)
{
	va_list args;
	va_start(args, format);
	for (const char *p = format; *p; p++)
	{
		if (*p != '%')
		{
			uioPrintChar(*p);
		}
		else
		{
			enum pfState state = FLAGS;

			enum pfFlagAlign align = RIGHT;
			enum pfFlagSign sign = NONE;
			int alternate = 0;
			int fieldWidth = 0;
			int precision = -1;
			enum pfLength length = DEFAULT;
			char buffer[24];
			char *outputStart = buffer + 23;
			char *outputEnd = buffer + 23;

			p++;
			while (state)
			{
				switch (state)
				{
				case FLAGS:
					switch (*p)
					{
						case '-':
							align = LEFT;
							p++;
							break;
						case '0':
							if (align != LEFT)
								align = ZPAD;
							p++;
							break;
						case '+':
							sign = PLUS;
							p++;
							break;
						case ' ':
							if (sign != PLUS)
								sign = SPACE;
							p++;
							break;
						case '#':
							alternate = -1;
							p++;
							break;
						default:
							state = FIELD_WIDTH;
							break;
					}
					break;
				case FIELD_WIDTH:
					if (*p >= '0' && *p <= '9')
					{
						fieldWidth *= 10;
						fieldWidth += (*p++ - '0');

					}
					else
					{
						state = DOT;
					}
					break;
				case DOT:
					switch (*p)
					{
					case '.':
						p++;
						precision = 0;
						state = PRECISION;
						break;
					default:
						state = LENGTH;
						break;
					}
					break;
				case PRECISION:
					if (*p >= '0' && *p <= '9')
					{
						precision *= 10;
						precision += (*p++ - '0');
					}
					else
					{
						state = LENGTH;
					}
					break;
				case LENGTH:
					switch (*p)
					{
					case 'h':
						p++;
						if (*p == 'h')
						{
							p++;
							length = HH;
						}
						else
						{
							length = H;
						}
						state = CONVERSION;
						break;
					case 'l':
						p++;
						if (*p == 'l')
						{
							p++;
							length = LL;
						}
						else
						{
							length = L;
						}
						state = CONVERSION;
						break;
					case 'L':
						p++;
						length = BIGL;
						state = CONVERSION;
					default:
						state = CONVERSION;
						break;
					}
					break;
				case CONVERSION:
					switch (*p)
					{
					case '%':
						outputStart = buffer + 22;
						*outputStart = '%';
						*outputEnd = '\0';
						break;
					case 'c': // character
						outputStart = buffer + 22;
						*outputStart = (char)va_arg(args, int);
						*outputEnd = '\0';
						break;
					case 's': // string
						outputStart = va_arg(args, char*);
						if (precision < 0)
							for (outputEnd = outputStart; *outputEnd; outputEnd++);
						else
							outputEnd = outputStart + precision;
						break;
					case 'i':
					case 'd': // signed decimal
						switch (length)
						{
						case HH:
							outputStart = pfSignedDec(buffer, (signed char)va_arg(args, int));
							break;
						case H:
							outputStart = pfSignedDec(buffer, (short)va_arg(args, int));
							break;
						case DEFAULT:
							outputStart = pfSignedDec(buffer, va_arg(args, int));
							break;
						case L:
						case LL:
						case BIGL:
							outputStart = pfSignedDec(buffer, va_arg(args, long int));
							break;
						}
						break;
					case 'o': // unsigned octal
						switch (length)
						{
						case HH:
							outputStart = pfUnsigned(buffer, (unsigned char)va_arg(args, unsigned int), 8);
							break;
						case H:
							outputStart = pfUnsigned(buffer, (unsigned short)va_arg(args, unsigned int), 8);
							break;
						case DEFAULT:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned int), 8);
							break;
						case L:
						case LL:
						case BIGL:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned long int), 8);
							break;
						}
						break;
					case 'u': // unsigned decimal
						switch (length)
						{
						case HH:
							outputStart = pfUnsigned(buffer, (unsigned char)va_arg(args, unsigned int), 10);
							break;
						case H:
							outputStart = pfUnsigned(buffer, (unsigned short)va_arg(args, unsigned int), 10);
							break;
						case DEFAULT:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned int), 10);
							break;
						case L:
						case LL:
						case BIGL:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned long int), 10);
							break;
						}
						break;
					case 'x': // unsigned hex (lower case)
						switch (length)
						{
						case HH:
							outputStart = pfUnsigned(buffer, (unsigned char)va_arg(args, unsigned int), 16);
							break;
						case H:
							outputStart = pfUnsigned(buffer, (unsigned short)va_arg(args, unsigned int), 16);
							break;
						case DEFAULT:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned int), 16);
							break;
						case L:
						case LL:
						case BIGL:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned long int), 16);
							break;
						}
						break;
					case 'p': // pointer
						outputStart = pfUnsigned(buffer, va_arg(args, unsigned int), 16);
						for (int i = 8 - (outputEnd - outputStart); i > 0; i--)
						{
							--outputStart;
							*outputStart = '0';
						}
						break;
					case 'X': // unsigned hex (upper case)
						switch (length)
						{
						case HH:
							outputStart = pfUnsigned(buffer, (unsigned char)va_arg(args, unsigned int), 16);
							break;
						case H:
							outputStart = pfUnsigned(buffer, (unsigned short)va_arg(args, unsigned int), 16);
							break;
						case DEFAULT:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned int), 16);
							break;
						case L:
						case LL:
						case BIGL:
							outputStart = pfUnsigned(buffer, va_arg(args, unsigned long int), 16);
							break;
						}
						break;
					default:
						*outputEnd = '\0';
						outputStart = outputEnd;
					}
					state = END;
					break;
				case END:
					break;
				} // switch (state)
			} // while (state)

			int len = outputEnd - outputStart;

			char prefix[3];
			for (int i = 0; i < 3; i++) // no access to memset
				prefix[i] = 0; // = {0,0,0};

			if (sign != NONE && (*p == 'i' || *p == 'd') && *outputStart != '-')
			{
				prefix[0] = sign;
				len++;
			}
			else if (alternate && *outputStart != '0')
			{
				if (*p == 'o')
				{
					prefix[0] = '0';
					len++;
				}
				else if (*p == 'x')
				{
					prefix[0] = '0';
					prefix[1] = 'x';
					len += 2;
				}
				else if (*p == 'X' || *p == 'p')
				{
					prefix[0] = '0';
					prefix[1] = 'x';
					len += 2;
				}
			}

			int zeroCount = 0;

			// for dioux
			if (*p == 'd' || *p == 'i' || *p == 'o' ||*p == 'p' || *p == 'u' || *p == 'x' || *p == 'X')
			{
				if (precision >= 0)
					zeroCount = precision - (outputEnd - outputStart);
				else if (align == ZPAD && fieldWidth > 0)
					zeroCount = fieldWidth - (outputEnd - outputStart);
			}

			if (zeroCount < 0)
				zeroCount = 0;

			len += zeroCount;

			if (len < fieldWidth && align == RIGHT)
				for (int i = fieldWidth - len; i > 0; i--)
					uioPrintChar(' ');
			uioPrint(prefix);


			for (int i = zeroCount; i > 0; i--)
					uioPrintChar('0');

			if (*p == 's' && precision >= 0)
			{
				uioPrintN(outputEnd-outputStart, outputStart);
			}
			else
			{
				uioPrint(outputStart);
			}

			if (len < fieldWidth && align == LEFT)
				for (int i = fieldWidth - len; i > 0; i--)
					uioPrintChar(' ');
		}
	}

	va_end(args);
}

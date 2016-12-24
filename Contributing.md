# Ukko Contribution Guidelines

For a constribution to be accepted, it must be submitted as a pull request,
and its commits must adhere to these guidelines.

## Text Formatting

Format Source code, commit messages, and human-readable text documents in
UTF-8. Use line-feed characters as line endings (Unix-style). If developing on
Windows, you may use Git's autocrlf configuration to automatically switch
between Windows- and Unix-style line endings.

## Git Commits

Keep extraneous commits to a minimum. If you try something experimental as
part of your contribution, squash the submitted commits so that they create a
single commit with the complete changes. Submit chains of commits only if each
commit is a complete change, and it would possibly make sense to branch off of
a single commit in the chain.

### Commit Messages

Write the first line of a commit message as a single sentance, in the
imperative, describing what the commit does, without a period at the end. Keep
in mind, the first line will show up in lists of commits and should describe
the nature of the commit sufficiently in such contexts. If additional
information is needed to explain the nature of a commit, add a blank second
line to the commit, and describe additional details in lines up to 72
characters long.

## Code Formatting

Write all code in assembly or C. Name any global names that are exported (as
symbols) with an initial capital letter, and capitalize the first letter in
each word. Do not use underscors as word separators. Capitalize only the first
letter in an acronym or initialism. When naming exported objects, give
executable code (routines and functions) names in the imperative mood, and
data names as nouns or nominal phrases.

* Routine: `DoSomething`
* Routine: `GetAcpiInfo`
* Data: `SomeValue`
* Data: `SomeBiosValue`

### Assembly

Write assembly code in AT&T syntax for GNU as. If possible write it so that
Clang can also handle the code, unless this is not possible, such as with
16-bit code. Stage 1 images must be coded to fit in whatever boot size they
allow, 512 bytes for BIOS-based floppy disks and hard disks. You may break any
other guidelines to meet this requirement.

### C

Put statements on their own lines. Declare a single variable per line, and
initialize the variable on the line where it is declared. Don't separate unary
`++` and `--` operators from their operands. Separate binary operators from
their opperands with a single space. If a line extends past 78 characters or
if it will make the code easier to read, you may optionally break a single
statement into multiple lines. Indent the second and subsequent lines with a
single tab, or, If needed for readability or to disambiguate with nearby
blocks of code, with two tabs. Start 'continuation' lines with an operator
rather than an operand if possible. When comparing a variable with a constant,
use the variable as the left-side operand and the constant as the right-side
operand. Use blank lines tp separate out logical sections of code within a
function. Use a blank line to separate top-level sections of code such as
structs, enums, and functions. Global variables need not be separated from
each other by blank lines, but this is allowed if the variables or groups of
variables are logically separate.

Indent code with a single tab character per level of indentation. Put opening
and closing brackets on their own lines, at the same indentation as the
statement they expand. Indent the contents of the block one more level than
the brackets and statement. If a for, do or while, statement has a single
statement in its body, indent the single statement on its own line imediately
after the for, do or while statement, without brackets. Do the same with if
and else statements if the if clause has a single statement, and the else
clause either has a single statement, or is omitted entirely. Otherwise, use
brackets with both. Also use brackets with if and else statements if there are
fewer else statements in a nested set of if/else statements than there are if
statements. With a do statement, write the while clause at the same
indentation as the do statement imediately after the indented single statement
or closing bracket. Always use brackets with switch statements. Indent case
labels at the same level as the switch statement. End every non-empty case
with either a break statement or with the word fallthrough in a comment.

```
int DoSomething(int inVar, int otherInVar)
{
	int localValue = 0;


	for (int i = 0; i <= inVar; i++)
		localValue++;

	switch(otherVar)
	{
	case 1:
		localValue += 2;
		break;
	case 2:
		localValue -= 3;
		// fallthrough
	case 3:
		Panic();
		break;
	default:
	}

	if(inVar > 2
		&& invar < 25
		&& otherInVar != 3)
	{
		DoAnotherThing(inVar);
	}
	else
	{
		int x = 2;
		do
		{
			x--;
			CalculateValue(x);
		}
		while (x != 0)
	}
	return inVar+otherInvar+6;
}
```

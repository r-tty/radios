/*
 * x-ray.c - a simple system debugging tool.
 * Copyright (c) 2003 RET & COM Research.
 */

#include <stdio.h>

/*
 * Main
 */
int main(int argc, char *argv[])
{
    char buf[80];
    while (1) {
	fgets(buf, sizeof(buf)-1, stdin);
    }
    return 0;
}

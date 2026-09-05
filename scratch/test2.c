#include <stdio.h>
void _swaju_unbuf(void) __attribute__((constructor));
void _swaju_unbuf(void) { setvbuf(stdout,0,4,0); setvbuf(stderr,0,4,0); }
int main() {
    printf("Hello\n");
    return 0;
}

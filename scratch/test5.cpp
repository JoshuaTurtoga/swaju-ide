#include <iostream>
#include <stdio.h>
using namespace std;
void _swaju_unbuf(void) __attribute__((constructor));
void _swaju_unbuf(void) { setvbuf(stdout,0,4,0); }
int main() {
    cout << "Hello\n";
    return 0;
}

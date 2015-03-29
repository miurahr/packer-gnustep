#!/bin/bash
set -e

if [ "${NCPU}" == "" ]; then
  NCPU=3
fi
echo "Compile concurrency is ${NCPU}!"

SRCDIR=/usr/local/src

sudo apt-get install -y aptitude
# Dependencies
sudo aptitude -y install build-essential git subversion ninja cmake make gcc g++
# Dependencies for GNUStep Base
sudo aptitude -y install libffi-dev libxml2-dev libgnutls-dev libicu-dev 
# Dependencies for libdispatch
sudo aptitude -y install libblocksruntime-dev libkqueue-dev libpthread-workqueue-dev autoconf libtool

install -d ${SRCDIR}
cd ${SRCDIR}
git clone git://github.com/nickhutchinson/libdispatch.git
svn co http://svn.gna.org/svn/gnustep/modules/core gnustep-core
svn co http://svn.gna.org/svn/gnustep/libs/libobjc2/trunk libobjc2
svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/cfe/trunk clang

cd ${SRCDIR}/llvm
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/opt/llvm -DCMAKE_BUILD_TYPE=Release ${SRCDIR}/llvm
make -j${NCPU}
make install

echo "export PATH=\$PATH:/opt/llvm/bin" >> /etc/profile.d/llvm.conf
echo "export CC=clang"  >> /etc/profile.d/llvm.conf
echo "export CXX=clang++" >> /etc/profile.d/llvm.conf
source /etc/profile.d/clang.conf
clang -v
clang++ -v

cd ${SRCDIR}/libobjc2
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/opt/llvm -DCMAKE_BUILD_TYPE=Release ${SRCDIR}/libobjc2
make -j${NCPU}
sudo -E make install

cd ${SRCDIR}/gnustep-core/make
./configure --enable-debug-by-default --with-layout=gnustep --enable-objc-nonfragile-abi --prefix=/opt/llvm
make && sudo -E make install

echo ". /opt/llvm/GNUstep/System/Library/Makefiles/GNUstep.sh" >> /etc/profile.d/llvm.conf
source /etc/profile.d/llvm.conf

echo "/opt/llvm/lib/x86_64-linux-gnu" > /etc/ld.so.conf.d/llvm.conf
echo "/opt/llvm/lib/x86_64-linux-gnu/libobjc2" >> /etc/ld.so.conf.d/llvm.conf
sudo /sbin/ldconfig

cd ${SRCDIR}/gnustep-core/base/
./configure --prefix=/opt/llvm
make -j${NCPU}
sudo -E make install

cd ${SRCDIR}/libdispatch
sh autogen.sh
./configure CFLAGS="-I/usr/include/kqueue" LDFLAGS="-lkqueue -lpthread_workqueue -pthread -lm" --prefix=/opt/llvm
make -j${NCPU}
sudo -E make install

echo "/opt/llvm/lib/x86_64-linux-gnu/libdispatch" >> /etc/ld.so.conf.d/llvm.conf
sudo ldconfig


# ----------------------------------------------------------------------------------------
# TEST COMPILING SOME CODE FROM THE INTERNET
# ----------------------------------------------------------------------------------------

install -d /tmp/llvm-test
cd /tmp/llvm-test

cat > blocktest.m << EOF
#include <stdio.h>

int main() {
    void (^hello)(void) = ^(void) {
        printf("Hello, block!\n");
    };
    hello();
    return 0;
}
EOF

clang `gnustep-config --objc-flags` `gnustep-config --objc-libs` -fobjc-runtime=gnustep -fblocks -fobjc-arc -lobjc  blocktest.m 

cat > helloGCD_objc.m << EOF

#include <dispatch/dispatch.h>
#import <stdio.h>
#import "Fraction.h"

int main( int argc, const char *argv[] ) {
   dispatch_queue_t queue = dispatch_queue_create(NULL, NULL); 
   Fraction *frac = [[Fraction alloc] init];

   [frac setNumerator: 1];
   [frac setDenominator: 3];

   // print it
   dispatch_sync(queue, ^{
     printf( "The fraction is: " );
     [frac print];
     printf( "\n" );
   });
   dispatch_release(queue);

   return 0;
}

EOF

cat > Fraction.h << EOF

#import <Foundation/NSObject.h>

@interface Fraction: NSObject {
   int numerator;
   int denominator;
}

-(void) print;
-(void) setNumerator: (int) n;
-(void) setDenominator: (int) d;
-(int) numerator;
-(int) denominator;
@end

EOF


cat > Fraction.m << EOF
#import "Fraction.h"
#import <stdio.h>

@implementation Fraction
-(void) print {
   printf( "%i/%i", numerator, denominator );
}

-(void) setNumerator: (int) n {
   numerator = n;
}

-(void) setDenominator: (int) d {
   denominator = d;
}

-(int) denominator {
   return denominator;
}

-(int) numerator {
   return numerator;
}
@end

EOF

clang `gnustep-config --objc-flags` `gnustep-config --objc-libs` -fobjc-runtime=gnustep -fblocks -lobjc -ldispatch -lgnustep-base  Fraction.m helloGCD_objc.m


rm -rf /tmp/llvm-test

# ------------------------------------------------------
# STEP 2:  INSTALLING GUI AND BACK
# (i.e., if you're running Ubuntu Desktop)
# ------------------------------------------------------

sudo aptitude install -y libjpeg-dev libtiff-dev libffi-dev
sudo aptitude install -y libcairo-dev libx11-dev:i386 libxt-dev

cd ${SRCDIR}/gnustep-core/gui
./configure --prefix=/opt/llvm
make -j${NCPU}
sudo -E make install

cd ${SRCDIR}/gnustep-core/back
./configure --prefix=/opt/llvm
make -j${NCPU}
sudo -E make install

install -d /tmp/llvm-test
cd /tmp/llvm-test

cat > guitest.m << EOF
#import <AppKit/AppKit.h>

int main()
{
  NSApplication *app;  // Without these 2 lines, seg fault may occur
  app = [NSApplication sharedApplication];

  NSAlert * alert = [[NSAlert alloc] init];
  [alert setMessageText:@"Hello alert"];
  [alert addButtonWithTitle:@"All done"];
  int result = [alert runModal];
  if (result == NSAlertFirstButtonReturn) {
    NSLog(@"First button pressed");
  }
}
EOF

clang `gnustep-config --objc-flags` `gnustep-config --objc-libs`  -fobjc-runtime=gnustep -fblocks -lobjc -fobjc-arc -ldispatch -lgnustep-base -lgnustep-gui  guitest.m

rm -rf /tmp/llvm-test

exit 0

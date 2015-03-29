sudo apt-get install aptitude
# Dependencies
sudo aptitude -y install build-essential git subversion ninja cmake
# Dependencies for GNUStep Base
sudo aptitude -y install libffi-dev libxml2-dev libgnutls-dev libicu-dev 
# Dependencies for libdispatch
sudo aptitude -y install libblocksruntime-dev libkqueue-dev libpthread-workqueue-dev autoconf libtool

cd ~
git clone git://github.com/nickhutchinson/libdispatch.git
svn co http://svn.gna.org/svn/gnustep/modules/core
svn co http://svn.gna.org/svn/gnustep/libs/libobjc2/trunk libobjc2
svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/cfe/trunk clang

cd ~/llvm
mkdir build
cd build
cmake ..
make -j8   # 8=your number of build CPUs

echo "export PATH=\$PATH:~/llvm/build/bin" >> ~/.bashrc
echo "export CC=clang"  >> ~/.bashrc
echo "export CXX=clang++" >> ~/.bashrc
source ~/.bashrc
clang -v
clang++ -v

cd ~/libobjc2
mkdir build
cd build
cmake ..
make -j8
sudo -E make install

cd ~/core/make
./configure --enable-debug-by-default --with-layout=gnustep --enable-objc-nonfragile-abi
make && sudo -E make install
echo ". /usr/GNUstep/System/Library/Makefiles/GNUstep.sh" >> ~/.bashrc
source ~/.bashrc

sudo /sbin/ldconfig

cd ~/core/base/
./configure
make -j8
sudo -E make install

cd ~/libdispatch
sh autogen.sh
./configure CFLAGS="-I/usr/include/kqueue" LDFLAGS="-lkqueue -lpthread_workqueue -pthread -lm"
make -j8
sudo -E make install
sudo ldconfig

# ----------------------------------------------------------------------------------------
# TEST COMPILING SOME CODE FROM THE INTERNET
# ----------------------------------------------------------------------------------------

You can compile the following code with:

clang `gnustep-config --objc-flags` `gnustep-config --objc-libs` -fobjc-runtime=gnustep -fblocks -fobjc-arc -lobjc  blocktest.m 

clang `gnustep-config --objc-flags` `gnustep-config --objc-libs` -fobjc-runtime=gnustep -fblocks -lobjc -ldispatch -lgnustep-base  Fraction.m helloGCD_objc.m



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


# ------------------------------------------------------
# STEP 2:  INSTALLING GUI AND BACK
# (i.e., if you're running Ubuntu Desktop)
# ------------------------------------------------------

sudo aptitude install -y libjpeg-dev libtiff-dev libffi-dev
sudo aptitude install -y libcairo-dev libx11-dev:i386 libxt-dev

cd ~/core/gui
./configure
make -j8
sudo -E make install

cd ~/core/back
./configure
make -j8
sudo -E make install

You can compile the following code with:

clang `gnustep-config --objc-flags` `gnustep-config --objc-libs`  -fobjc-runtime=gnustep -fblocks -lobjc -fobjc-arc -ldispatch -lgnustep-base -lgnustep-gui  guitest.m



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

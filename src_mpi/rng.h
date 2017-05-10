#include "Random123/threefry.h"
#include "Random123/u01fixedpt.h"

/* 
threefryrand() generates random doubles in the range [0.0,1.0]
using an algorithm from the Random123 library.

Initialize by calling set_threefry_array with a user-supplied
seed. 

For multi-threaded situations, the user-supplied seed should
be different for each thread if one seeks to avoid having
the same stream of random numbers for each thread/process.

 */
static threefry4x64_ctr_t ctr={{}};
static threefry4x64_key_t key={{}};

void increment_counter() {
  static size_t index = 0;
  ctr.v[index++ % 4]++;
}

void set_threefry_array(unsigned int user_key) {
  key.v[0] = user_key;
  key.v[1] = user_key;
  key.v[2] = user_key;
  key.v[3] = user_key;
}

double threefryrand() {
  static size_t randomNumberIndex = 4;
  static threefry4x64_ctr_t result={{}};
  if (!(randomNumberIndex % 4)) {
    result = threefry4x64(ctr, key);
    randomNumberIndex -= 4;
    increment_counter();
  }
  return u01fixedpt_closed_closed_64_53(result.v[randomNumberIndex++]);
}


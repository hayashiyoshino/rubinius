/* This file was generated by Ragel. Your edits will be lost.
 *
 * This is a state machine implementation of String#unpack.
 * See http://github.com/brixen/rapa.
 *
 * vim: filetype=cpp
 */

#include <sstream>

#include "vm/config.h"

#include "vm.hpp"
#include "object_utils.hpp"
#include "on_stack.hpp"
#include "objectmemory.hpp"

#include "builtin/array.hpp"
#include "builtin/exception.hpp"
#include "builtin/fixnum.hpp"
#include "builtin/float.hpp"
#include "builtin/string.hpp"

namespace rubinius {

  namespace unpack {
    void inline increment(native_int& index, native_int n, native_int limit) {
      if(index + n < limit) {
        index += n;
      } else {
        index = limit;
      }
    }

    uint16_t swap_2bytes(uint16_t x) {
      return ((((x)&0xff)<<8) | (((x)>>8)&0xff));
    }

    uint32_t swap_4bytes(uint32_t x) {
      return ((((x)&0xff)<<24)
             |(((x)>>24)&0xff)
             |(((x)&0x0000ff00)<<8)
             |(((x)&0x00ff0000)>>8));
    }

    uint64_t swap_8bytes(uint64_t x) {
      return ((((x)&0x00000000000000ffLL)<<56)
             |(((x)&0xff00000000000000LL)>>56)
             |(((x)&0x000000000000ff00LL)<<40)
             |(((x)&0x00ff000000000000LL)>>40)
             |(((x)&0x0000000000ff0000LL)<<24)
             |(((x)&0x0000ff0000000000LL)>>24)
             |(((x)&0x00000000ff000000LL)<<8)
             |(((x)&0x000000ff00000000LL)>>8));
    }

    float swap_float(const uint8_t* str) {
      uint32_t x;
      float y;

      memcpy(&x, str, sizeof(uint32_t));
      x = swap_4bytes(x);
      memcpy(&y, &x, sizeof(float));

      return y;
    }

    double swap_double(const uint8_t* str) {
      uint64_t x;
      double y;

      memcpy(&x, str, sizeof(uint64_t));
      x = swap_8bytes(x);
      memcpy(&y, &x, sizeof(double));

      return y;
    }

    inline int hex2num(char c) {
      switch (c) {
      case '0': case '1': case '2': case '3': case '4':
      case '5': case '6': case '7': case '8': case '9':
        return c - '0';
      case 'a': case 'b': case 'c':
      case 'd': case 'e': case 'f':
        return c - 'a' + 10;
      case 'A': case 'B': case 'C':
      case 'D': case 'E': case 'F':
        return c - 'A' + 10;
      default:
        return -1;
      }
    }

    String* quotable_printable(STATE, const char*& bytes,
                               const char* bytes_end, native_int remainder)
    {
      if(remainder == 0) {
        return String::create(state, 0, 0);
      }

      String* str = String::create(state, 0, remainder);
      uint8_t *buf = str->byte_address();

      while(bytes < bytes_end) {
        if(*bytes == '=') {
          if(++bytes == bytes_end)
            break;

          if(bytes+1 < bytes_end && bytes[0] == '\r' && bytes[1] == '\n')
            bytes++;

          if(*bytes != '\n') {
            int c1, c2;

            if((c1 = hex2num(*bytes)) == -1)
              break;
            if(++bytes == bytes_end)
              break;
            if((c2 = hex2num(*bytes)) == -1)
              break;
            *buf++ = c1 << 4 | c2;
          }
        } else {
          *buf++ = *bytes;
        }
        bytes++;
      }

      *buf = 0;
      str->num_bytes(state, Fixnum::from(buf - str->byte_address()));

      return str;
    }

    String* base64_decode(STATE, const char*& bytes,
                          const char* bytes_end, native_int remainder)
    {
      if(remainder == 0) {
        return String::create(state, 0, 0);
      }

      static bool initialized = false;
      static signed char b64_xtable[256];

      if(!initialized) {
        initialized = true;

        for(int i = 0; i < 256; i++) {
          b64_xtable[i] = -1;
        }

        for(int i = 0; i < 64; i++) {
          static const char table[] =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
          b64_xtable[(int)(table[i])] = i;
        }
      }

      native_int num_bytes = (bytes_end - bytes) * 3 / 4;
      String* str = String::create(state, 0, num_bytes);
      uint8_t *buf = str->byte_address();

      int a = -1, b = -1, c = 0, d = 0;
      while(bytes < bytes_end) {
        a = b = c = d = -1;

        while((a = b64_xtable[(int)(*bytes)]) == -1 && bytes < bytes_end)
          bytes++;
        if(bytes >= bytes_end)
          break;
        bytes++;

        while((b = (int)b64_xtable[(int)(*bytes)]) == -1 && bytes < bytes_end)
          bytes++;
        if(bytes >= bytes_end)
          break;
        bytes++;

        while((c = (int)b64_xtable[(int)(*bytes)]) == -1 && bytes < bytes_end) {
          if(*bytes == '=')
            break;
          bytes++;
        }
        if(*bytes == '=' || bytes >= bytes_end)
          break;
        bytes++;

        while((d = (int)b64_xtable[(int)(*bytes)]) == -1 && bytes < bytes_end) {
          if(*bytes == '=')
            break;
          bytes++;
        }
        if(*bytes == '=' || bytes >= bytes_end)
          break;
        bytes++;

        *buf++ = a << 2 | b >> 4;
        *buf++ = b << 4 | c >> 2;
        *buf++ = c << 6 | d;
      }

      if(a != -1 && b != -1) {
        if(c == -1 && *bytes == '=') {
          *buf++ = a << 2 | b >> 4;
        } else if(c != -1 && *bytes == '=') {
          *buf++ = a << 2 | b >> 4;
          *buf++ = b << 4 | c >> 2;
        }
      }

      *buf = 0;
      str->num_bytes(state, Fixnum::from(buf - str->byte_address()));
      return str;
    }

    String* uu_decode(STATE, const char*& bytes,
                      const char* bytes_end, native_int remainder)
    {
      if(remainder == 0) {
        return String::create(state, 0, 0);
      }

      native_int length = 0, num_bytes = (bytes_end - bytes) * 3 / 4;
      String* str = String::create(state, 0, num_bytes);
      uint8_t *buf = str->byte_address();

      while(bytes < bytes_end && *bytes > ' ' && *bytes < 'a') {
        native_int line = (*bytes++ - ' ') & 0x3f;
        length += line;
        if(length > num_bytes) {
          line -= length - num_bytes;
          length = num_bytes;
        }

        while(line > 0) {
          char values[4];
          int l = line > 3 ? 3 : line;

          for(int i = 0; i < 4; i++) {
            if(bytes < bytes_end && *bytes >= ' ') {
              values[i] = (*bytes++ - ' ') & 0x3f;
            } else {
              values[i] = 0;
            }
          }

          switch(l) {
          case 3:
            buf[2] = values[2] << 6 | values[3];
          case 2:
            buf[1] = values[1] << 4 | values[2] >> 2;
          case 1:
            buf[0] = values[0] << 2 | values[1] >> 4;
          }

          buf += l;
          line -= l;
        }

        if(*bytes == '\r') bytes++;
        if(*bytes == '\n') {
          bytes++;
        } else if(bytes < bytes_end && (bytes+1 == bytes_end || bytes[1] == '\n')) {
          // possible checksum byte
          bytes += 2;
        }
      }

      buf[length] = 0;
      str->num_bytes(state, Fixnum::from(length));
      return str;
    }

    static const int32_t utf8_limits[] = {
      0x0,        /* 1 */
      0x80,       /* 2 */
      0x800,      /* 3 */
      0x10000,    /* 4 */
      0x200000,   /* 5 */
      0x4000000,  /* 6 */
      0x80000000, /* 7 */
    };

#define MALFORMED_UTF8_ERROR_SIZE 60

    void utf8_decode(STATE, Array* array,
                     const char* bytes, const char* bytes_end,
                     native_int count, native_int& index)
    {
      int length;

      for(; count > 0 && bytes < bytes_end; count--) {
        native_int remainder = bytes_end - bytes;
        int32_t c = *bytes++ & 0xff, value = c;
        int n = 0;
        length = 1;

        if(value & 0x80) {
          if(!(value & 0x40)) {
            Exception::argument_error(state, "malformed UTF-8 character");
          }

          if(!(value & 0x20)) {
            n = 2;
            value &= 0x1f;
          } else if(!(value & 0x10)) {
            n = 3;
            value &= 0x0f;
          } else if(!(value & 0x08)) {
            n = 4;
            value &= 0x07;
          } else if(!(value & 0x04)) {
            n = 5;
            value &= 0x03;
          } else if(!(value & 0x02)) {
            n = 6;
            value &= 0x01;
          } else {
            Exception::argument_error(state, "malformed UTF-8 character");
          }

          if(n > remainder) {
            char error_msg[MALFORMED_UTF8_ERROR_SIZE];
            snprintf(error_msg, MALFORMED_UTF8_ERROR_SIZE,
                    "malformed UTF-8 character (expected %d bytes, given %d bytes)",
                    n, (int)remainder);
            Exception::argument_error(state, error_msg);
          }

          length = n--;
          if(n != 0) {
            while(n--) {
              c = *bytes++ & 0xff;
              if((c & 0xc0) != 0x80) {
                Exception::argument_error(state, "malformed UTF-8 character");
              } else {
                c &= 0x3f;
                value = value << 6 | c;
              }
            }
          }

          if(value < utf8_limits[length-1]) {
            Exception::argument_error(state, "redundant UTF-8 sequence");
          }
        }

        array->append(state, Integer::from(state, value));
        index += length;
      }
    }

    void ber_decode(STATE, Array* array,
                     const char*& bytes, const char* bytes_end,
                     native_int count, native_int& index)
    {
      static unsigned long mask = 0xfeUL << ((sizeof(unsigned long) - 1) * 8);
      static Fixnum* base = Fixnum::from(128);
      unsigned long value = 0;

      while(count > 0 && bytes < bytes_end) {
        value <<= 7;
        value |= (*bytes & 0x7f);
        if(!(*bytes++ & 0x80)) {
          array->append(state, Integer::from(state, value));
          count--;
          value = 0;
        } else if(value & mask) {
          Integer* result = Integer::from(state, value);

          while(bytes < bytes_end) {
            if(result->fixnum_p()) {
              result = as<Fixnum>(result)->mul(state, base);
            } else {
              result = as<Bignum>(result)->mul(state, base);
            }

            Fixnum* b = Fixnum::from(*bytes & 0x7f);
            if(result->fixnum_p()) {
              result = as<Fixnum>(result)->add(state, b);
            } else {
              result = as<Bignum>(result)->add(state, b);
            }

            if(!(*bytes++ & 0x80)) {
              if(result->fixnum_p()) {
                array->append(state, result);
              } else {
                array->append(state, Bignum::normalize(state, as<Bignum>(result)));
              }
              count--;
              value = 0;
              break;
            }
          }
        }
      }
    }

    String* bit_high(STATE, const char*& bytes, native_int count) {
      String* str = String::create(state, 0, count);
      uint8_t *buf = str->byte_address();
      int bits = 0;

      for(native_int i = 0; i < count; i++) {
        if(i & 7) {
          bits <<= 1;
        } else {
          bits = *bytes++;
        }

        buf[i] = (bits & 128) ? '1' : '0';
      }

      return str;
    }

    String* bit_low(STATE, const char*& bytes, native_int count) {
      String* str = String::create(state, 0, count);
      uint8_t *buf = str->byte_address();
      int bits = 0;

      for(native_int i = 0; i < count; i++) {
        if(i & 7) {
          bits >>= 1;
        } else {
          bits = *bytes++;
        }

        buf[i] = (bits & 1) ? '1' : '0';
      }

      return str;
    }

    static const char hexdigits[] = "0123456789abcdef0123456789ABCDEFx";

    String* hex_high(STATE, const char*& bytes, native_int count) {
      String* str = String::create(state, 0, count);
      uint8_t *buf = str->byte_address();
      int bits = 0;

      for(native_int i = 0; i < count; i++) {
        if(i & 1) {
          bits <<= 4;
        } else {
          bits = *bytes++;
        }

        buf[i] = unpack::hexdigits[(bits >> 4) & 15];
      }

      return str;
    }

    String* hex_low(STATE, const char*& bytes, native_int count) {
      String* str = String::create(state, 0, count);
      uint8_t *buf = str->byte_address();
      int bits = 0;

      for(native_int i = 0; i < count; i++) {
        if(i & 1) {
          bits >>= 4;
        } else {
          bits = *bytes++;
        }

        buf[i] = unpack::hexdigits[bits & 15];
      }

      return str;
    }
  }

#define unpack_elements(create, bits)                     \
  for(; index < stop; index += width) {                   \
    const uint8_t* bytes = self->byte_address() + index;  \
    array->append(state, create(bits(bytes)));            \
    if(count > 0) count--;                                \
  }

#define UNPACK_ELEMENTS unpack_elements
#define unpack_integer(b)         unpack_elements(new_integer, b)
#define unpack_float_elements(b)  unpack_elements(new_float, b)

#define FIXNUM(b)         (Fixnum::from(b))
#define INTEGER(b)        (Integer::from(state, b))

#define new_integer(b)    (Integer::from(state, b))
#define new_float(b)      (Float::create(state, b))

#define sbyte(p)          (*(int8_t*)(p))
#define ubyte(p)          (*(uint8_t*)(p))

#define s2bytes(p)        (*(int16_t*)(p))
#define u2bytes(p)        (*(uint16_t*)(p))

#define s4bytes(p)        (*(int32_t*)(p))
#define u4bytes(p)        (*(uint32_t*)(p))

#define s8bytes(p)        (*(int64_t*)(p))
#define u8bytes(p)        (*(uint64_t*)(p))

#define float_bits(p)     (*(float*)(p))
#define double_bits(p)    (*(double*)(p))

#ifdef RBX_LITTLE_ENDIAN

# define s2bytes_le(p)            (s2bytes(p))
# define u2bytes_le(p)            (u2bytes(p))
# define s4bytes_le(p)            (s4bytes(p))
# define u4bytes_le(p)            (u4bytes(p))
# define s8bytes_le(p)            (s8bytes(p))
# define u8bytes_le(p)            (u8bytes(p))

# define s2bytes_be(p)            ((int16_t)(unpack::swap_2bytes(u2bytes(p))))
# define u2bytes_be(p)            ((uint16_t)(unpack::swap_2bytes(u2bytes(p))))
# define s4bytes_be(p)            ((int32_t)(unpack::swap_4bytes(u4bytes(p))))
# define u4bytes_be(p)            ((uint32_t)(unpack::swap_4bytes(u4bytes(p))))
# define s8bytes_be(p)            ((int64_t)(unpack::swap_8bytes(u8bytes(p))))
# define u8bytes_be(p)            ((uint64_t)(unpack::swap_8bytes(u8bytes(p))))

# define unpack_double            unpack_double_le
# define unpack_float             unpack_float_le

# define unpack_double_le         unpack_float_elements(double_bits)
# define unpack_float_le          unpack_float_elements(float_bits)

# define unpack_double_be         unpack_float_elements(unpack::swap_double)
# define unpack_float_be          unpack_float_elements(unpack::swap_float)

#else // Big endian

# define s2bytes_le(p)            ((int16_t)(unpack::swap_2bytes(u2bytes(p))))
# define u2bytes_le(p)            ((uint16_t)(unpack::swap_2bytes(u2bytes(p))))
# define s4bytes_le(p)            ((int32_t)(unpack::swap_4bytes(u4bytes(p))))
# define u4bytes_le(p)            ((uint32_t)(unpack::swap_4bytes(u4bytes(p))))
# define s8bytes_le(p)            ((int64_t)(unpack::swap_8bytes(u8bytes(p))))
# define u8bytes_le(p)            ((uint64_t)(unpack::swap_8bytes(u8bytes(p))))

# define s2bytes_be(p)            (s2bytes(p))
# define u2bytes_be(p)            (u2bytes(p))
# define s4bytes_be(p)            (s4bytes(p))
# define u4bytes_be(p)            (u4bytes(p))
# define s8bytes_be(p)            (s8bytes(p))
# define u8bytes_be(p)            (u8bytes(p))

# define unpack_double            unpack_double_be
# define unpack_float             unpack_float_be

# define unpack_double_le         unpack_float_elements(unpack::swap_double)
# define unpack_float_le          unpack_float_elements(unpack::swap_float)

# define unpack_double_be         unpack_float_elements(double_bits)
# define unpack_float_be          unpack_float_elements(float_bits)

#endif

  Array* String::unpack(STATE, String* directives) {
    // Ragel-specific variables
    std::string d(directives->c_str(), directives->size());
    const char *p  = d.c_str();
    const char *pe = p + d.size();

    const char *eof = pe;
    int cs;

    // pack-specific variables
    String* self = this;
    Array* array = Array::create(state, 0);
    OnStack<2> sv(state, self, array);
    const char* bytes = 0;
    const char* bytes_end = 0;

    native_int bytes_size = self->size();
    native_int index = 0;
    native_int stop = 0;
    native_int width = 0;
    native_int count = 0;
    native_int remainder = 0;
    bool rest = false;
    bool platform = false;

%%{
  machine unpack;

  include "unpack.rl";

}%%

    if(en_main) {
      // do nothing
    }

    return force_as<Array>(Primitives::failure());
  }
}

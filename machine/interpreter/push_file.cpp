
#include "instructions/push_file.hpp"

namespace rubinius {
  namespace interpreter {
    intptr_t push_file(STATE, CallFrame* call_frame, intptr_t const opcodes[]) {
      instructions::push_file(state, call_frame);

      call_frame->next_ip(instructions::data_push_file.width);
      return ((instructions::Instruction)opcodes[call_frame->ip()])(state, call_frame, opcodes);
    }
  }
}

#ifndef RBX_TEST_TEST_HPP
#define RBX_TEST_TEST_HPP

#include "vm.hpp"
#include "state.hpp"
#include "call_frame.hpp"
#include "config_parser.hpp"
#include "machine/object_utils.hpp"
#include "memory.hpp"
#include "configuration.hpp"
#include "metrics.hpp"
#include "machine/detection.hpp"
#include "machine/memory/immix_marker.hpp"
#include "class/executable.hpp"
#include "class/method_table.hpp"
#include "class/thread.hpp"

#include <cxxtest/TestSuite.h>

using namespace rubinius;

class RespondToToAry {
public:
  template <class T>
    static Object* create(STATE) {
      Class* klass = Class::create(state, G(object));

      Symbol* to_ary_sym = state->symbol("to_ary");
      Executable* to_ary = Executable::allocate(state, cNil);
      to_ary->primitive(state, to_ary_sym);
      to_ary->set_executor(T::to_ary);

      klass->method_table()->store(state, to_ary_sym, nil<String>(), to_ary,
          nil<LexicalScope>(), Fixnum::from(0), G(sym_public));

      Object* obj = state->memory()->new_object<Object>(state, klass);

      return obj;
    }
};

class RespondToToAryReturnNull : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnNull>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    return nullptr;
  }
};

class RespondToToAryReturnFixnum : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnFixnum>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    return Fixnum::from(42);
  }
};

class RespondToToAryReturnArray : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnArray>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    Array* ary = Array::create(state, 1);
    ary->set(state, 0, Fixnum::from(42));

    return ary;
  }
};

class RespondToToAryReturnNonArray : public RespondToToAry {
public:
  static Object* create(STATE) {
    return RespondToToAry::create<RespondToToAryReturnNonArray>(state);
  }

  static Object* to_ary(STATE, Executable* exec, Module* mod, Arguments& args) {
    return Fixnum::from(42);
  }
};

class VMTest {
public:
  SharedState* shared;
  State* state;
  ConfigParser* config_parser;
  Configuration config;


  void setup_call_frame(CallFrame* cf, StackVariables* scope, int size) {
    scope->initialize(cNil, cNil, Module::create(state), 0);

    cf->prepare(size);
    cf->stack_ptr_ = cf->stk - 1;
    cf->previous = NULL;
    cf->lexical_scope_ = nil<LexicalScope>();
    cf->dispatch_data = NULL;
    cf->compiled_code = nil<CompiledCode>();
    cf->flags = 0;
    cf->top_scope_ = NULL;
    cf->scope = scope;
    cf->arguments = NULL;
  }

  CompiledCode* setup_compiled_code(int iseq_length, int arg_length) {
    CompiledCode* code = CompiledCode::create(state);

    code->iseq(state, InstructionSequence::create(state, iseq_length));
    code->total_args(state, Fixnum::from(arg_length));
    code->required_args(state, code->total_args());
    code->post_args(state, code->total_args());
    code->stack_size(state, Fixnum::from(0));

    return code;
  }

  // TODO: Fix this
  void initialize_as_root(VM* vm) {
    vm->set_current_thread();

    Memory* om = new Memory(vm, vm->shared);
    vm->shared.om = om;

    vm->shared.set_initialized();
    vm->shared.set_root_vm(vm);

    vm->managed_phase(state);

    State state(vm);

    TypeInfo::auto_learn_fields(&state);

    vm->bootstrap_ontology(&state);

    // Setup the main Thread, which is wrapper of the main native thread
    // when the VM boots.
    Thread::create(&state, vm);
    vm->thread()->alive(&state, cTrue);
    vm->thread()->sleep(&state, cFalse);
  }

  void create() {
    config_parser = new ConfigParser;
    shared = new SharedState(0, config, *config_parser);
    VM* vm = shared->thread_nexus()->new_vm(shared);
    initialize_as_root(vm);
    state = new State(vm);
  }

  void destroy() {
    if(Memory* om = state->memory()) {
      if(memory::ImmixMarker* im = om->immix_marker()) {
        im->stop(state);
      }
    }

    VM::discard(state, state->vm());
    delete shared;
    delete state;
  }

  void setUp() {
    create();
  }

  void tearDown() {
    destroy();
  }
};

#endif

define("chuck/instructions", ["chuck/ugen", "chuck/logging"], (ugen, logging) ->
  module = {}

  callMember = (vm) ->
    localDepth = vm.popFromReg()
    func = vm.popFromReg()
    stackDepth = func.stackDepth
    args = []
    i = 0
    while i < stackDepth
      args.unshift(vm.popFromReg())
      ++i
    thisObj = undefined
    if func.needThis
      thisObj = args.shift()
    func.apply(thisObj, args)

  class Instruction
    constructor: (name, params, execute) ->
      @instructionName = name
      _(@).extend(params)
      @_executeCb = execute

    execute: (vm) =>
      if !@_executeCb
        return
      @_executeCb.call(@, vm)

  module.instantiateObject = (type) ->
    return new Instruction("InstantiateObject", type: type, (vm) ->
      logging.debug("Instantiating object of type #{type.name}")
      ug = new ugen.UGen(type)
      vm.addUgen(ug)
      vm.pushToReg(ug)
    )

  module.allocWord = (offset) ->
    return new Instruction("AllocWord", offset: offset, (vm) ->
      # Push memory stack index of value
      vm.pushToReg(@offset)
    )

  module.popWord = ->
    return new Instruction("PopWord", undefined, (vm) ->
      vm.popFromReg()
    )

  module.preConstructor = (type, stackOffset) ->
    return new Instruction("PreConstructor", type: type, stackOffset: stackOffset, (vm) ->
      # Duplicate top of stack, which should be object pointer
      logging.debug("Calling pre-constructor of #{@type.name}")
      # Push 'this' reference
      vm.pushToReg(vm.peekReg())
      # Signal that this function needs a 'this' reference
      @type.preConstructor.needThis = true
      @type.preConstructor.stackDepth = 1
      vm.pushToReg(@type.preConstructor)
      vm.pushToReg(@stackOffset)

      callMember(vm)
    )

  module.assignObject = ->
    return new Instruction("AssignObject", {}, (vm) ->
      memStackIndex = vm.popFromReg()
      obj = vm.popFromReg()
      vm.insertIntoMemory(memStackIndex, obj)
      vm.pushToReg(obj)
      return undefined
    )

  module.dac = ->
    return new Instruction("Dac", {}, (vm) ->
      vm.pushDac()
      return undefined
    )

  module.releaseObject2 = (offset) ->
    return new Instruction("ReleaseObject2", offset: offset, (vm) ->
      vm.removeFromMemory(offset)
      return undefined
    )

  module.eoc = -> return new Instruction("Eoc")

  module.uGenLink = -> return new Instruction("UGenLink", {}, (vm) ->
    dest = vm.popFromReg()
    src = vm.popFromReg()
    dest.add(src)
    return undefined
  )

  module.regPushImm = (val) -> return new Instruction("RegPushImm", val: val, (vm) ->
    vm.pushToReg(val)
    return undefined
  )

  module.timesNumber = -> return new Instruction("TimesNumber", {}, (vm) ->
    lhs = vm.popFromReg()
    rhs = vm.popFromReg()
    vm.pushToReg(lhs*rhs)
    return undefined
  )

  module.regPushNow = -> return new Instruction("RegPushNow", {}, (vm) ->
    vm.pushNow()
    return undefined
  )

  module.addNumber = -> return new Instruction("AddNumber", {}, (vm) ->
    lhs = vm.popFromReg()
    rhs = vm.popFromReg()
    vm.pushToReg(lhs+rhs)
    return undefined
  )

  module.timeAdvance = -> return new Instruction("TimeAdvance", {}, (vm) ->
    time = vm.popFromReg()
    vm.suspendUntil(time)
    vm.pushToReg(time)
    return undefined
  )

  return module
)

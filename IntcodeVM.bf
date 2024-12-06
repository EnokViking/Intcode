using System;
using System.Diagnostics;
using System.Collections;

namespace Random;

class IntcodeVM
{
	public enum Opcode : uint8
	{
		ADD 	= 0x1,
		MUL 	= 0x2,
		READ 	= 0x3,
		WRITE 	= 0x4,
		JIT 	= 0x5,
		JIF		= 0x6,
		LESS	= 0x7,
		CMP		= 0x8,
		RBO		= 0x9,
		HALT 	= 0x63
	}

	private int _relativeBase = 0;
	private int _instructionPointer = 0;

	private append Queue<int> _input = .();
	private readonly Span<int> _roMemory;
	private 		 Span<int> _rwMemory;
	private 		 Span<int> _register; //Parameters modes & output [first, second, third][output]
	
	[AllowAppend]
	public this(Span<int> tokens, int extraMemory = 0)
	{
		var extraMemory;
		extraMemory /= sizeof(int);

		/*
		     source length     + 	   extra	   + 	source length	  + 	4
		-------READWRITE-------|-------EXTRA-------|-------READONLY-------|--REGISTER--
		-------READWRITE-------|-------EXTRA-------|-------READONLY-------|--REGISTER--
		*/
		let mem = append int[tokens.Length * 2 + extraMemory + 4]*;

		Internal.MemSet(mem + tokens.Length, 0, extraMemory * sizeof(int));

		_rwMemory = .(mem, tokens.Length + extraMemory);
		_roMemory = .(mem + tokens.Length + extraMemory, tokens.Length);
		_register = .(mem + tokens.Length + extraMemory + tokens.Length, 4);

		for (int i < tokens.Length) {
			_roMemory[i] = tokens[i];
			_rwMemory[i] = tokens[i];
		}

		Debug.Assert(_rwMemory.Length - extraMemory == _roMemory.Length);
		Debug.Assert(Internal.MemCmp(_rwMemory.Ptr, _roMemory.Ptr, _roMemory.Length * sizeof(int)) == 0);
	}

	public void Reset()
	{
		_instructionPointer = 0;
		for (let i < _roMemory.Length)
			_rwMemory[i] = _roMemory[i];

		Debug.Assert(Internal.MemCmp(_rwMemory.Ptr, _roMemory.Ptr, _roMemory.Length * sizeof(int)) == 0);
	}

	public Opcode Step(function bool(Opcode op) shouldExecute)
	{
		let instruction = _rwMemory[_instructionPointer];
		let op = GetOpcode(instruction);

		if (shouldExecute == null || shouldExecute(op)) {
			_instructionPointer += ExecuteOp(op);
		}

		return op;
	}

	public void Run() { while (Step(null) != .HALT) {} }

	public void WriteIn(int val) => _input.Add(val);
	public int ReadOut() => _register[3];

	public void PatchMemory(int addr, int val) => _rwMemory[addr] = val;
	public int PeekMemory(int addr) => _rwMemory[addr];
	
	private int ExecuteOp(Opcode op)
	{
		switch ((op, _register[0], _register[1])) {

			case (.MUL, 0, 0): return MUL_0_0();
			case (.MUL, 0, 1): return MUL_0_1();
			case (.MUL, 1, 0): return MUL_1_0();
			case (.MUL, 1, 1): return MUL_1_1();

			//Relative base
			case (.MUL, 0, 2): return MUL_0_2();
			case (.MUL, 2, 0): return MUL_2_0();
			case (.MUL, 1, 2): return MUL_1_2();
			case (.MUL, 2, 1): return MUL_2_1();
			case (.MUL, 2, 2): return MUL_2_2();

			case (.ADD, 0, 0): return ADD_0_0();
			case (.ADD, 0, 1): return ADD_0_1();
			case (.ADD, 1, 0): return ADD_1_0();
			case (.ADD, 1, 1): return ADD_1_1();

			//Relative base
			case (.ADD, 0, 2): return ADD_0_2();
			case (.ADD, 2, 0): return ADD_2_0();
			case (.ADD, 1, 2): return ADD_1_2();
			case (.ADD, 2, 1): return ADD_2_1();
			case (.ADD, 2, 2): return ADD_2_2();

			case (.JIT, 0, 0): return JIT_0_0();
 			case (.JIT, 0, 1): return JIT_0_1();
			case (.JIT, 1, 0): return JIT_1_0();
			case (.JIT, 1, 1): return JIT_1_1();

			//Relative base
			case (.JIT, 0, 2): return JIT_0_2();
			case (.JIT, 2, 0): return JIT_2_0();
			case (.JIT, 1, 2): return JIT_1_2();
			case (.JIT, 2, 1): return JIT_2_1();
			case (.JIT, 2, 2): return JIT_2_2();

			case (.JIF, 0, 0): return JIF_0_0();
			case (.JIF, 0, 1): return JIF_0_1();
			case (.JIF, 1, 0): return JIF_1_0();
			case (.JIF, 1, 1): return JIF_1_1();

			//Relative base
			case (.JIF, 0, 2): return JIF_0_2();
			case (.JIF, 2, 0): return JIF_2_0();
			case (.JIF, 1, 2): return JIF_1_2();
			case (.JIF, 2, 1): return JIF_2_1();
			case (.JIF, 2, 2): return JIF_2_2();

			case (.LESS, 0, 0): return LESS_0_0();
 			case (.LESS, 0, 1): return LESS_0_1();
			case (.LESS, 1, 0): return LESS_1_0();
			case (.LESS, 1, 1): return LESS_1_1();

			//Relative base
			case (.LESS, 0, 2): return LESS_0_2();
			case (.LESS, 2, 0): return LESS_2_0();
			case (.LESS, 1, 2): return LESS_1_2();
			case (.LESS, 2, 1): return LESS_2_1();
			case (.LESS, 2, 2): return LESS_2_2();

			case (.CMP, 0, 0): return CMP_0_0();
			case (.CMP, 0, 1): return CMP_0_1();
			case (.CMP, 1, 0): return CMP_1_0();
			case (.CMP, 1, 1): return CMP_1_1();

			//Relative base
			case (.CMP, 0, 2): return CMP_0_2();
			case (.CMP, 2, 0): return CMP_2_0();
			case (.CMP, 1, 2): return CMP_1_2();
			case (.CMP, 2, 1): return CMP_2_1();
			case (.CMP, 2, 1): return CMP_2_2();

			case (.READ, 0, ?): _rwMemory[_rwMemory[_instructionPointer + 1]] = _input.PopFront(); return 2;
			case (.READ, 2, ?): _rwMemory[_rwMemory[_instructionPointer + 1] + _relativeBase] = _input.PopFront(); return 2;

			case (.WRITE, 0, ?): _register[3] = _rwMemory[_rwMemory[_instructionPointer + 1]]; return 2;
			case (.WRITE, 1, ?): _register[3] = _rwMemory[_instructionPointer + 1]; return 2;
			case (.WRITE, 2, ?): _register[3] = _rwMemory[_rwMemory[_instructionPointer + 1] + _relativeBase]; return 2;

			case (.RBO, 0, ?): _relativeBase += _rwMemory[_rwMemory[_instructionPointer + 1]]; return 2;
			case (.RBO, 1, ?): _relativeBase += _rwMemory[_instructionPointer + 1]; return 2;
			case (.RBO, 2, ?): _relativeBase += _rwMemory[_rwMemory[_instructionPointer + 1] + _relativeBase]; return 2;
		}

		return 0;
	}

	private Opcode GetOpcode(int i)
	{
		if (i == 99)
			return .HALT;

		let f = i % 10;

		//Set parameter modes
		_register[0] = (i / 100) % 10;
		_register[1] = (i / 1000) % 10;
		_register[2] = (i / 10000) % 10;

		switch (f) {
			case 01: return .ADD;
			case 02: return .MUL;
			case 03: return .READ;
			case 04: return .WRITE;
			case 05: return .JIT;
			case 06: return .JIF;
			case 07: return .LESS;
			case 08: return .CMP;
			case 09: return .RBO;
		}

		Runtime.FatalError(scope $"Unknown opcode encountered. {f}");
	}

	#region instructions
	[Inline]
	private int CMP_0_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] == _rwMemory[rop] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int CMP_0_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] == rop ? 1 : 0;

		return 4;
	}

	[Inline]
	private int CMP_1_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop == _rwMemory[rop] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int CMP_1_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop == rop ? 1 : 0;

		return 4;
	}

	[Inline]
	private int CMP_0_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] == _rwMemory[rop + _relativeBase] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int CMP_2_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] == _rwMemory[rop] ? 1 : 0;

		return 4;
	}
	
	[Inline]
	private int CMP_1_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop == _rwMemory[rop + _relativeBase] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int CMP_2_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] == rop ? 1 : 0;

		return 4;
	}

	[Inline]
	private int CMP_2_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] == _rwMemory[rop + _relativeBase] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_0_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] < _rwMemory[rop] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_0_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] < rop ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_1_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop < _rwMemory[rop] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_1_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop < rop ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_0_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] < _rwMemory[rop + _relativeBase] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_2_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] < rop ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_1_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop < _rwMemory[rop + _relativeBase] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_2_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] < rop ? 1 : 0;

		return 4;
	}

	[Inline]
	private int LESS_2_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] < _rwMemory[rop + _relativeBase] ? 1 : 0;

		return 4;
	}

	[Inline]
	private int JIT_0_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop] != 0) {
			_instructionPointer = _rwMemory[rop];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_0_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop] != 0) {
			_instructionPointer = rop;
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_1_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (lop != 0) {
			_instructionPointer = _rwMemory[rop];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_1_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (lop != 0) {
			_instructionPointer = rop;
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_0_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop] != 0) {
			_instructionPointer = _rwMemory[rop + _relativeBase];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_2_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop + _relativeBase] != 0) {
			_instructionPointer = _rwMemory[rop];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_1_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (lop != 0) {
			_instructionPointer = _rwMemory[rop + _relativeBase];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_2_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop + _relativeBase] != 0) {
			_instructionPointer = rop;
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIT_2_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop + _relativeBase] != 0) {
			_instructionPointer = _rwMemory[rop + _relativeBase];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_0_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop] == 0) {
			_instructionPointer = _rwMemory[rop];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_0_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop] == 0) {
			_instructionPointer = rop;
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_1_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (lop == 0) {
			_instructionPointer = _rwMemory[rop];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_1_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (lop == 0) {
			_instructionPointer = rop;
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_0_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop] == 0) {
			_instructionPointer = _rwMemory[rop + _relativeBase];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_2_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop + _relativeBase] == 0) {
			_instructionPointer = _rwMemory[rop];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_1_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (lop == 0) {
			_instructionPointer = _rwMemory[rop + _relativeBase];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_2_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop + _relativeBase] == 0) {
			_instructionPointer = rop;
			return 0;
		}

		return 3;
	}

	[Inline]
	private int JIF_2_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];

		if (_rwMemory[lop + _relativeBase] == 0) {
			_instructionPointer = _rwMemory[rop + _relativeBase];
			return 0;
		}

		return 3;
	}

	[Inline]
	private int ADD_0_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] + _rwMemory[rop];
		return 4;
	}

	[Inline]
	private int ADD_0_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] + rop;
		return 4;
	}

	[Inline]
	private int ADD_1_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop + _rwMemory[rop];
		return 4;
	}

	[Inline]
	private int ADD_1_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop + rop;
		return 4;
	}

	[Inline]
	private int ADD_0_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] + _rwMemory[rop + _relativeBase];
		return 4;
	}

	[Inline]
	private int ADD_2_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] + _rwMemory[rop];
		return 4;
	}

	[Inline]
	private int ADD_1_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop + _rwMemory[rop + _relativeBase];
		return 4;
	}

	[Inline]
	private int ADD_2_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] + rop;
		return 4;
	}

	[Inline]
	private int ADD_2_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] + _rwMemory[rop + _relativeBase];
		return 4;
	}

	[Inline]
	private int MUL_0_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] * _rwMemory[rop];
		return 4;
	}

	[Inline]
	private int MUL_0_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] * rop;
		return 4;
	}

	[Inline]
	private int MUL_1_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop * _rwMemory[rop];
		return 4;
	}

	[Inline]
	private int MUL_1_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop * rop;
		return 4;
	}

	[Inline]
	private int MUL_0_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop] * _rwMemory[rop + _relativeBase];
		return 4;
	}

	[Inline]
	private int MUL_2_0()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] * _rwMemory[rop];
		return 4;
	}

	[Inline]
	private int MUL_2_1()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] * rop;
		return 4;
	}

	[Inline]
	private int MUL_1_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = lop * _rwMemory[rop + _relativeBase];
		return 4;
	}

	[Inline]
	private int MUL_2_2()
	{
		let lop = _rwMemory[_instructionPointer + 1];
		let rop = _rwMemory[_instructionPointer + 2];
		let sop = _rwMemory[_instructionPointer + 3];

		let rba = (_register[2] == 2 ? _relativeBase : 0);
		_rwMemory[sop + rba] = _rwMemory[lop + _relativeBase] * _rwMemory[rop + _relativeBase];
		return 4;
	}
	#endregion
}
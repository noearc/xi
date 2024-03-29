import Fraction from require "xi.fraction"

describe("Fraction", ->
	it("should new with arguments", ->
		f = Fraction!
		assert.are.equal(f.numerator, 0)
		assert.are.equal(f.denominator, 1)
		f = Fraction(3, 4)
		assert.are.equal(f.numerator, 3)
		assert.are.equal(f.denominator, 4)
		f = Fraction(6, 8)
		assert.are.equal(f.numerator, 3)
		assert.are.equal(f.denominator, 4)
		f = Fraction(-4, 8)
		assert.are.equal(f.numerator, -1)
		assert.are.equal(f.denominator, 2)
		f = Fraction(4, -8)
		assert.are.equal(f.numerator, -1)
		assert.are.equal(f.denominator, 2)
		f = Fraction(-4, -8)
		assert.are.equal(f.numerator, 1)
		assert.are.equal(f.denominator, 2)
		-- Does Fraction need to reduce decimal numbers to closest approximation?
		f = Fraction(1.5)
		assert.are.equal(f.numerator, 3)
		assert.are.equal(f.denominator, 2)

		f = Fraction(-1.5)
		assert.are.equal(f.numerator, -3)
		assert.are.equal(f.denominator, 2)

		f = Fraction(0.777)
		assert.are.equal(f.numerator, 777)
		assert.are.equal(f.denominator, 1000)

		f = Fraction(0.0)
		assert.are.equal(f.numerator, 0)
		assert.are.equal(f.denominator, 1)
	)

	it("should throw on divide by zero", ->
		assert.has_error( ->
			Fraction(1, 0)
		)
	)

	-- Does Fraction need to infer fraction from string representation?
	--function TestFractional__new__fromString()
	--    f = Fraction("1/2")
	--    assert.are.equal(f:numerator, 1)
	--    assert.are.equal(f:denominator, 2)
	--
	it("should add", ->
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 2)
		assert.are.equal(f1 + f2, Fraction(1))
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 3)
		-- 3/6 + 2/6
		assert.are.equal(f1 + f2, Fraction(5, 6))
		f1 = Fraction(1, 2)
		f2 = Fraction(-1, 3)
		-- 3/6 + -2/6
		assert.are.equal(f1 + f2, Fraction(1, 6))
	)

	it("should subtract", ->
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 2)
		assert.are.equal(f1 - f2, Fraction(0))
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 3)
		-- 3/6 - 2/6
		assert.are.equal(f1 - f2, Fraction(1, 6))
		f1 = Fraction(1, 2)
		f2 = Fraction(-1, 3)
		-- 3/6 - -2/6
		assert.are.equal(f1 - f2, Fraction(5, 6))
	)

	it("should multiply", ->
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 2)
		assert.are.equal(f1 * f2, Fraction(1, 4))
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 3)
		assert.are.equal(f1 * f2, Fraction(1, 6))
		f1 = Fraction(1, 2)
		f2 = Fraction(-1, 3)
		assert.are.equal(f1 * f2, Fraction(-1, 6))
	)
	it("should divide", ->
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 2)
		assert.are.equal(f1 / f2, Fraction(1))
		f1 = Fraction(1, 2)
		f2 = Fraction(1, 3)
		assert.are.equal(f1 / f2, Fraction(3, 2))
		f1 = Fraction(1, 2)
		f2 = Fraction(-1, 3)
		assert.are.equal(f1 / f2, Fraction(-3, 2))
	)

	it("should support mod", ->
		f1 = Fraction(1, 2)
		f2 = Fraction(2, 3)
		assert.are.equal(f1 % f2, Fraction(1, 2))
		f1 = Fraction(3, 4)
		f2 = Fraction(2, 3)
		-- 9/12 % 8/12 = 1/12
		assert.are.equal(f1 % f2, Fraction(1, 12))
	)

	it("should be able to be raised to a power", ->
		f1 = Fraction(1, 4)
		f2 = Fraction(1, 2)
		assert.are.equal(f1 ^ f2, 0.5)
		f1 = Fraction(1, 4)
		f2 = Fraction(2, 1)
		assert.are.equal(f1 ^ f2, Fraction(1, 16))
	)

	it("should support negative operator", ->
		f1 = Fraction(1, 4)
		assert.are.equal(-f1, Fraction(-1, 4))
	)

	it("should be able to be floored", ->
		f1 = Fraction(1, 4)
		assert.are.equal(f1\floor(), 0)
		f1 = Fraction(5, 4)
		assert.are.equal(f1\floor(), 1)
		f1 = Fraction(9, 4)
		assert.are.equal(f1\floor(), 2)
	)

	it("should support greater than comparison", ->
		assert.is_true(Fraction(3, 4) > Fraction(1, 3))
		assert.is_true(Fraction(5, 4) > Fraction(1, 1))
		assert.is_false(Fraction(1, 3) > Fraction(1, 2))
		assert.is_false(Fraction(5, 4) > Fraction(7, 4))
	)

	it("should support less than comparison", ->
		assert.is_true(Fraction(1, 4) < Fraction(1, 3))
		assert.is_true(Fraction(1, 4) < Fraction(1, 3))
		assert.is_true(Fraction(5, 4) < Fraction(7, 3))
		assert.is_false(Fraction(2, 3) < Fraction(1, 2))
		assert.is_false(Fraction(9, 1) < Fraction(7, 4))
	)

	it("should support greater than or equal to comparison", ->
		assert.is_true(Fraction(3, 4) >= Fraction(1, 3))
		assert.is_true(Fraction(1, 3) >= Fraction(1, 3))
		assert.is_true(Fraction(-1, 3) >= Fraction(-7, 3))
		assert.is_true(Fraction(5, 4) >= Fraction(5, 4))
		assert.is_false(Fraction(1, 3) >= Fraction(1, 2))
		assert.is_false(Fraction(5, 4) >= Fraction(7, 4))
	)

	it("should support less than or equal to comparison", ->
		assert.is_true(Fraction(1, 4) <= Fraction(1, 3))
		assert.is_true(Fraction(1, 4) <= Fraction(1, 4))
		assert.is_true(Fraction(5, 4) <= Fraction(7, 3))
		assert.is_true(Fraction(-5, 4) <= Fraction(7, 3))
		assert.is_false(Fraction(2, 3) <= Fraction(1, 2))
		assert.is_false(Fraction(9, 1) <= Fraction(7, 4))
	)

	it("should support equal to comparison", ->
		assert.is_true(Fraction(1, 4) == Fraction(1, 4))
		assert.is_true(Fraction(5, 4) == Fraction(10, 8))
		assert.is_true(Fraction(-2, 3) == Fraction(8, -12))
		assert.is_true(Fraction(-1, 3) == Fraction(-3, 9))
		assert.is_false(Fraction(254, 255) == Fraction(255, 256))
	)

	it("should support min", ->
		assert.are.equal(Fraction(3, 4)\min(Fraction(5, 6)), Fraction(3, 4))
		assert.are.equal(Fraction(3, 4)\min(Fraction(3, 6)), Fraction(3, 6))
		assert.are.equal(Fraction(3, 4)\min(Fraction(-5, 6)), Fraction(-5, 6))
		assert.are.equal(Fraction(-3, 4)\min(Fraction(-5, 6)), Fraction(-5, 6))
	)

	it("should support max", ->
		assert.are.equal(Fraction(3, 4)\max(Fraction(5, 6)), Fraction(5, 6))
		assert.are.equal(Fraction(3, 4)\max(Fraction(3, 6)), Fraction(3, 4))
		assert.are.equal(Fraction(3, 4)\max(Fraction(-5, 6)), Fraction(3, 4))
		assert.are.equal(Fraction(-3, 4)\max(Fraction(-5, 6)), Fraction(-3, 4))
	)

	it("should show string representation", ->
		assert.are.equal(Fraction(1, 2)\show(), "1/2")
	)
)

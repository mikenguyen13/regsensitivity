test_that("real_roots returns sorted real solutions only", {
    # x^2 - 1 has roots +/- 1
    expect_equal(sort(regsensitivity:::real_roots(c(-1, 0, 1))), c(-1, 1))
    # x^2 + 1 has no real roots
    expect_length(regsensitivity:::real_roots(c(1, 0, 1)), 0)
    # constant has no roots
    expect_length(regsensitivity:::real_roots(c(5)), 0)
    # trailing zeros stripped
    expect_equal(sort(regsensitivity:::real_roots(c(-1, 0, 1, 0))), c(-1, 1))
})

test_that("polymult and polyadd match base R", {
    a <- c(1, 2, 3)
    b <- c(0, 1, 4)
    # increasing-order: a(x) = 1 + 2x + 3x^2, b(x) = x + 4x^2
    # product = x + 4x^2 + 2x^2 + 8x^3 + 3x^3 + 12x^4 = x + 6x^2 + 11x^3 + 12x^4
    expect_equal(regsensitivity:::polymult(a, b),
                  c(0, 1, 6, 11, 12))
    # sum with padding
    expect_equal(regsensitivity:::polyadd(c(1, 2), c(0, 0, 5)),
                  c(1, 2, 5))
})

test_that("polyderiv is correct for first derivative", {
    # f(x) = 3 + 4x + 5x^2 + 6x^3 -> f'(x) = 4 + 10x + 18x^2
    expect_equal(regsensitivity:::polyderiv(c(3, 4, 5, 6)),
                  c(4, 10, 18))
})

test_that("cummin_inf and cummax_neg_inf treat NA as identity", {
    expect_equal(regsensitivity:::cummin_inf(c(3, 2, NA, 1, 4)),
                  c(3, 2, 2, 1, 1))
    expect_equal(regsensitivity:::cummax_neg_inf(c(-3, NA, -1, -2, 0)),
                  c(-3, -3, -1, -1, 0))
})

test_that("expand_numlist handles space-separated, range, and numeric", {
    expect_equal(regsensitivity:::expand_numlist(c(0, .5, 1)), c(0, .5, 1))
    expect_equal(regsensitivity:::expand_numlist("0 .5 1"), c(0, .5, 1))
    expect_equal(regsensitivity:::expand_numlist("0(.5)1"), c(0, .5, 1))
    expect_length(regsensitivity:::expand_numlist(""), 0)
})

test_that("clip respects element-wise bounds", {
    expect_equal(regsensitivity:::clip(c(-1, 0, 1, 2), 0, 1.5),
                  c(0, 0, 1, 1.5))
})

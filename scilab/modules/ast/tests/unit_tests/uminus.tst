// ============================================================================
// Scilab ( http://www.scilab.org/ ) - This file is part of Scilab
// Copyright (C) 2014 - Scilab Enterprises - Bruno JOFRET
//
//  This file is distributed under the same license as the Scilab package.
// ============================================================================

// <-- JVM NOT MANDATORY -->

assert_checkequal([1, -1], [1 -1]);
assert_checkequal(0, [1 - 1]);
a = 42;
assert_checkequal([1, -a], [1 -a]);
assert_checkequal([(1 - a)], [1 - a]);
assert_checkequal([1, - a + 2], [1 -(a - 2)]);
assert_checkequal([(1 - a + 2)], [1 - a + 2]);
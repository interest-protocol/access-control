// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

/*
* @author Jose Cerqueira
* @notice This module provides errors for the access control contract.
*/
module access_control::errors;

// === Errors ===

public(package) macro fun invalid_otw(): u64 {
    0
}

public(package) macro fun invalid_epoch(): u64 {
    1
}

public(package) macro fun invalid_admin(): u64 {
    2
}

public(package) macro fun invalid_super_admin(): u64 {
    3
}

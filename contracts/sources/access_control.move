// Copyright (c) DEFI, LDA
// SPDX-License-Identifier: Apache-2.0

/*
* @author Jose Cerqueira
* @notice This module provides a safe access control mechanism for the contract. 
* The SuperAdmin object has the ability to add and remove admins from the contract. 
* Admins can create a Witness to execute authorized transactions. 
*/
module access_control::access_control;

use access_control::{errors, events};
use std::u64;
use sui::{types, vec_set::{Self, VecSet}};

// === Imports ===

// === Constants ===

// @dev Each epoch is roughly 1 day
const THREE_EPOCHS: u64 = 3;

// === Structs ===

public struct AdminWitness<phantom T>() has drop;

public struct SuperAdmin<phantom T> has key {
    id: UID,
    new_admin: address,
    start: u64,
}

public struct Admin<phantom T> has key, store {
    id: UID,
}

public struct ACL<phantom T> has key, store {
    id: UID,
    admins: VecSet<address>,
}

// === Public Mutative Functions ===

public fun new<OTW: drop>(otw: OTW, super_admin_recipient: address, ctx: &mut TxContext): ACL<OTW> {
    assert!(types::is_one_time_witness(&otw), errors::invalid_otw!());
    assert!(super_admin_recipient != @0x0, errors::invalid_super_admin!());

    let acl = ACL<OTW> {
        id: object::new(ctx),
        admins: vec_set::empty(),
    };

    let super_admin = SuperAdmin<OTW> {
        id: object::new(ctx),
        new_admin: @0x0,
        start: u64::max_value!(),
    };

    transfer::transfer(super_admin, super_admin_recipient);

    acl
}

public fun new_admin<OTW: drop>(
    acl: &mut ACL<OTW>,
    _: &SuperAdmin<OTW>,
    ctx: &mut TxContext,
): Admin<OTW> {
    let admin = Admin {
        id: object::new(ctx),
    };

    acl.admins.insert(admin.id.to_address());

    events::new_admin<OTW>(admin.id.to_address());

    admin
}

public fun revoke<OTW: drop>(acl: &mut ACL<OTW>, _: &SuperAdmin<OTW>, to_revoke: address) {
    acl.admins.remove(&to_revoke);

    events::revoke_admin<OTW>(to_revoke);
}

public fun is_admin<OTW: drop>(acl: &ACL<OTW>, admin: address): bool {
    acl.admins.contains(&admin)
}

public fun sign_in<OTW: drop>(acl: &ACL<OTW>, admin: &Admin<OTW>): AdminWitness<OTW> {
    assert!(acl.is_admin( admin.id.to_address()), errors::invalid_admin!());

    AdminWitness()
}

public fun destroy_admin<OTW: drop>(acl: &mut ACL<OTW>, admin: Admin<OTW>) {
    let Admin { id } = admin;

    let admin_address = id.to_address();

    if (acl.admins.contains(&admin_address)) acl.admins.remove(&admin_address);

    id.delete();
}

// === Transfer Super Admin ===

public fun start_transfer<OTW: drop>(
    super_admin: &mut SuperAdmin<OTW>,
    new_super_admin: address,
    ctx: &mut TxContext,
) {
    //@dev Destroy it instead for the Sui rebate
    assert!(
        new_super_admin != @0x0 && new_super_admin != ctx.sender(),
        errors::invalid_super_admin!(),
    );

    super_admin.start = ctx.epoch();
    super_admin.new_admin = new_super_admin;

    events::start_super_admin_transfer<OTW>(new_super_admin, super_admin.start);
}

public fun finish_transfer<OTW: drop>(mut super_admin: SuperAdmin<OTW>, ctx: &mut TxContext) {
    assert!(ctx.epoch() > super_admin.start + THREE_EPOCHS, errors::invalid_epoch!());

    let new_admin = super_admin.new_admin;
    super_admin.new_admin = @0x0;
    super_admin.start = u64::max_value!();

    transfer::transfer(super_admin, new_admin);

    events::finish_super_admin_transfer<OTW>(new_admin);
}

// @dev This is irreversible, the contract does not offer a way to create a new super admin
public fun destroy_super_admin<OTW: drop>(super_admin: SuperAdmin<OTW>) {
    let SuperAdmin { id, .. } = super_admin;
    id.delete();
}

// === Aliases ===

public use fun destroy_super_admin as SuperAdmin.destroy;

// === Test Functions ===

#[test_only]
public fun sign_in_for_testing<OTW: drop>(): AdminWitness<OTW> {
    AdminWitness()
}

#[test_only]
public fun admins<OTW: drop>(acl: &ACL<OTW>): &VecSet<address> {
    &acl.admins
}

#[test_only]
public fun super_admin_new_admin<OTW: drop>(super_admin: &SuperAdmin<OTW>): address {
    super_admin.new_admin
}

#[test_only]
public fun super_admin_start<OTW: drop>(super_admin: &SuperAdmin<OTW>): u64 {
    super_admin.start
}

#[test_only]
public fun admin_address<OTW: drop>(admin: &Admin<OTW>): address {
    admin.id.to_address()
}

#[test_only]
public use fun admin_address as Admin.address;

#[test_only]
public use fun super_admin_new_admin as SuperAdmin.new_admin;

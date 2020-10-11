import pytest
import brownie
import math


@pytest.fixture
def hex_contract(Contract):
    # deploy the contract with the initial value as a constructor argument
    yield Contract.from_explorer("0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39")


@pytest.fixture
def liquidstake_contract(liquidstake, hex_contract, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield liquidstake.deploy(hex_contract, {'from': accounts[0]})


def test_balance(hex_contract, accounts):
    assert hex_contract.balanceOf(accounts[0]) == 0


def test_stake_without_any_hex(hex_contract, liquidstake_contract, accounts):
    hex_contract.approve(liquidstake_contract, 100 * 1e8, {'from': accounts[0]})
    with brownie.reverts():
        liquidstake_contract.stake(100 * 1e8, 365, {'from': accounts[0]})

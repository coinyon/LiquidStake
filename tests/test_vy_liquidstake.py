import pytest
import math

HEX_SUPPLY = 4000

@pytest.fixture
def mockhex_contract(MockHEX, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield MockHEX.deploy(HEX_SUPPLY, {'from': accounts[0]})


@pytest.fixture
def liquidstake_contract(LiquidStakeVyper, mockhex_contract, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield LiquidStakeVyper.deploy(
            "LiquidStake",
            "LS",
            mockhex_contract,
            mockhex_contract, {'from': accounts[0]}
        )


def test_balance(mockhex_contract, accounts):
    assert mockhex_contract.balanceOf(accounts[0]) == HEX_SUPPLY * 1e8


def test_stake(mockhex_contract, liquidstake_contract, accounts):
    mockhex_contract.approve(liquidstake_contract, 100 * 1e8, {'from': accounts[0]})
    liquidstake_contract.stake(100 * 1e8, 365)
    assert liquidstake_contract.ownerOf(1) == accounts[0]
    liquidstake_contract.endStake(1)


def test_two_stakes(mockhex_contract, liquidstake_contract, accounts):
    mockhex_contract.approve(liquidstake_contract, 200 * 1e8, {'from': accounts[0]})
    liquidstake_contract.stake(100 * 1e8, 365)
    assert liquidstake_contract.ownerOf(1) == accounts[0]
    liquidstake_contract.stake(100 * 1e8, 365)
    assert liquidstake_contract.ownerOf(2) == accounts[0]
    liquidstake_contract.endStake(1)
    liquidstake_contract.endStake(2)

import pytest
import math

HEX_SUPPLY = 4000
HEX_DECIMALS = 18


@pytest.fixture
def liquidstake_contract(liquidstake, mockhex_contract, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield liquidstake.deploy(mockhex_contract, {'from': accounts[0]})


@pytest.fixture
def mockhex_contract(mockhex, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield mockhex.deploy("HEX", "HEX", HEX_DECIMALS, HEX_SUPPLY, {'from': accounts[0]})


def test_balance(mockhex_contract, accounts):
    assert mockhex_contract.balanceOf(accounts[0]) == HEX_SUPPLY * math.pow(10, HEX_DECIMALS)


def test_stake(mockhex_contract, liquidstake_contract, accounts):
    DECS = math.pow(10, HEX_DECIMALS)
    mockhex_contract.approve(liquidstake_contract, 100 * DECS, {'from': accounts[0]})
    nft = liquidstake_contract.stake(100 * DECS, 365)
    #assert mockhex_contract.storedData() == INITIAL_VALUE

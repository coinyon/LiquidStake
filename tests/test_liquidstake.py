import pytest
import math

HEX_SUPPLY = 4000


@pytest.fixture
def liquidstake_contract(liquidstake, mockhex_contract, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield liquidstake.deploy(mockhex_contract, {'from': accounts[0]})


@pytest.fixture
def mockhex_contract(mockhex, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield mockhex.deploy(HEX_SUPPLY, {'from': accounts[0]})


def test_balance(mockhex_contract, accounts):
    assert mockhex_contract.balanceOf(accounts[0]) == HEX_SUPPLY * 1e8


def test_stake(mockhex_contract, liquidstake_contract, accounts):
    mockhex_contract.approve(liquidstake_contract, 100 * 1e8, {'from': accounts[0]})
    nft = liquidstake_contract.stake(100 * 1e8, 365)
    #liquidstake_contract.unstake(nft)


def test_two_stakes(mockhex_contract, liquidstake_contract, accounts):
    mockhex_contract.approve(liquidstake_contract, 200 * 1e8, {'from': accounts[0]})
    nft1 = liquidstake_contract.stake(100 * 1e8, 365)
    nft2 = liquidstake_contract.stake(100 * 1e8, 365)
    #liquidstake_contract.unstake(nft1)
    #liquidstake_contract.unstake(nft2)

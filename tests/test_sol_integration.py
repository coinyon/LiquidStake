import math

import brownie
import pytest


@pytest.fixture(scope="session")
def hex_contract(Contract):
    # deploy the contract with the initial value as a constructor argument
    yield Contract.from_explorer("0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39")


@pytest.fixture(scope="session")
def uniswap_v1_hex(Contract):
    yield Contract.from_explorer("0x05cde89ccfa0ada8c88d5a23caaa79ef129e7883")


@pytest.fixture(scope="session")
def liquidstake_contract(LiquidStakeSolidity, hex_contract, accounts):
    # deploy the contract with the original hex contract as a constructor argument
    yield LiquidStakeSolidity.deploy(
            "LiquidStake",
            "LS",
            hex_contract,
            hex_contract,
            {'from': accounts[0]}
        )


def test_stake_without_any_hex(hex_contract, liquidstake_contract, accounts):
    hex_contract.transfer(hex_contract, hex_contract.balanceOf(accounts[0]), {'from': accounts[0]})
    assert hex_contract.balanceOf(accounts[0]) == 0
    hex_contract.approve(liquidstake_contract, 100 * 1e8, {'from': accounts[0]})
    with brownie.reverts():
        liquidstake_contract.stake(100 * 1e8, 365, {'from': accounts[0]})


def test_buy_and_stake_hex(hex_contract, uniswap_v1_hex, liquidstake_contract, accounts):
    # Buy at least 100 HEX (in the future we might need to use uniswap V2 here)
    uniswap_v1_hex.ethToTokenSwapInput(
        100 * 1e8,  # minimum amount of tokens to purchase
        9999999999,  # timestamp
        {
            "from": accounts[0],
            "value": "1 ether"
        }
    )

    # Stake all the HEX
    assert hex_contract.balanceOf(accounts[0]) > 0
    amt = hex_contract.balanceOf(accounts[0])
    hex_contract.approve(liquidstake_contract, amt, {'from': accounts[0]})
    stakeTx = liquidstake_contract.stake(amt, 365, {'from': accounts[0]})

    # Here we count 3 Transfers:
    # - HEX to LiquidStake
    # - HEX to Staking
    # - NFT to accounts[0]
    assert len(stakeTx.events['Transfer']) == 3
    assert len(stakeTx.events['StakeStart']) == 1

    stakeId = stakeTx.events['Transfer'][2]['tokenId']
    assert stakeId == stakeTx.events['StakeStart'][0]['stakeId']

    # We got no HEX anymore
    assert hex_contract.balanceOf(accounts[0]) == 0
    assert liquidstake_contract.ownerOf(stakeId) == accounts[0]

    unstakeTx = liquidstake_contract.endStake(0, stakeId, {'from': accounts[0]})
    #import ipdb; ipdb.set_trace()
    #assert hex_contract.balanceOf(accounts[0]) > 0

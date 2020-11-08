import math

import brownie
import pytest


@pytest.fixture(scope="session")
def hex_contract(Contract, interface):
    yield interface.IHEX("0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39")


@pytest.fixture(scope="session")
def uniswap_v1_hex(Contract, interface):
    yield interface.IUniswapV1("0x05cde89ccfa0ada8c88d5a23caaa79ef129e7883")


@pytest.fixture(scope="session")
def rewards_contract(LiquidStakeRewards, hex_contract, accounts):
    yield LiquidStakeRewards.deploy(
            accounts[0],
            hex_contract,
            hex_contract,
            hex_contract,
            {'from': accounts[0]}
        )


@pytest.fixture(scope="session")
def liquidstake_contract(LiquidStakeSolidity, hex_contract, rewards_contract, accounts):
    # deploy the contract with the original hex contract as a constructor argument
    liquidstake = LiquidStakeSolidity.deploy(
            "LiquidStake",
            "LS",
            hex_contract,
            rewards_contract,
            {'from': accounts[0]}
        )
    rewards_contract.setRewardsDistribution(liquidstake)
    yield liquidstake


@pytest.fixture(scope="session")
def dao_contract(LiquidStakeDAO, hex_contract, rewards_contract, liquidstake_contract, accounts):
    dao = LiquidStakeDAO.deploy("LiquidStakeDAO", "LSD", {'from': accounts[5]})
    rewards_contract.setStakingToken(dao, {'from': accounts[0]})
    yield dao


@pytest.fixture(scope="session")
def pool_mining_contract(LiquidStakePool, hex_contract, dao_contract, liquidstake_contract, accounts):
    pool = LiquidStakePool.deploy(
            accounts[5],
            accounts[5],
            dao_contract,
            liquidstake_contract,
            {'from': accounts[5]}
        )
    totalSupply = dao_contract.balanceOf(accounts[5])
    assert totalSupply > 0
    dao_contract.transfer(pool, totalSupply, {'from': accounts[5]})
    pool.notifyRewardAmount(totalSupply, {'from': accounts[5]})
    leftover = dao_contract.balanceOf(accounts[5])
    assert leftover == 0
    yield pool


def empty_account(erc20, account):
    if erc20.balanceOf(account) > 0:
        erc20.transfer(erc20, erc20.balanceOf(account), {'from': account})
    assert erc20.balanceOf(account) == 0


def test_transfer_and_push_rewards(hex_contract, uniswap_v1_hex, liquidstake_contract, rewards_contract, accounts):
    "Will stake for accounts[1] and endStake for accounts[2]"

    alice = accounts[1]
    bob = accounts[2]

    # Poor bob does not have HEX
    empty_account(hex_contract, bob)

    # Buy at least 100 HEX (in the future we might need to use uniswap V2 here)
    uniswap_v1_hex.ethToTokenSwapInput(
        100 * 1e8,  # minimum amount of tokens to purchase
        9999999999,  # timestamp
        {
            "from": alice,
            "value": "1 ether"
        }
    )

    # Stake all the HEX
    assert hex_contract.balanceOf(alice) > 0
    amt = hex_contract.balanceOf(alice)
    hex_contract.approve(liquidstake_contract, amt, {'from': alice})
    stakeTx = liquidstake_contract.stake(amt, 365, {'from': alice})

    assert len(stakeTx.events['Transfer']) == 3
    assert len(stakeTx.events['StakeStart']) == 1

    stakeId = stakeTx.events['Transfer'][2]['tokenId']
    assert stakeId == stakeTx.events['StakeStart'][0]['stakeId']

    # We got no HEX anymore
    assert hex_contract.balanceOf(alice) == 0
    assert liquidstake_contract.ownerOf(stakeId) == alice

    # This is the heart of this test
    liquidstake_contract.transferFrom(alice, bob, stakeId, {'from': alice})
    assert liquidstake_contract.ownerOf(stakeId) == bob

    with brownie.reverts():
        # alice can no longer endstake
        unstakeTx = liquidstake_contract.endStake(0, stakeId, {'from': alice})

    # but bob can!
    unstakeTx = liquidstake_contract.endStake(0, stakeId, {'from': bob})
    assert len(unstakeTx.events['Transfer']) >= 3
    assert len(unstakeTx.events['StakeEnd']) == 1

    # bob got some HEX after endstaking!
    assert hex_contract.balanceOf(bob) > 0
    with brownie.reverts('ERC721: owner query for nonexistent token'):
        liquidstake_contract.ownerOf(stakeId)

    assert hex_contract.balanceOf(rewards_contract) == 0
    liquidstake_contract.pushRewards()
    assert hex_contract.balanceOf(rewards_contract) > 0


def test_stake_earn_pool_token(hex_contract, uniswap_v1_hex,
        liquidstake_contract, rewards_contract, pool_mining_contract, accounts,
        dao_contract, chain):
    "Alice will stake her LiquidStake to earn some pool tokens"

    alice = accounts[1]
    empty_account(dao_contract, alice)

    # Alice buys least 100 HEX (in the future we might need to use uniswap V2 here)
    uniswap_v1_hex.ethToTokenSwapInput(
        100 * 1e8,  # minimum amount of tokens to purchase
        9999999999,  # timestamp
        {
            "from": alice,
            "value": "1 ether"
        }
    )

    # Stake all the HEX
    assert hex_contract.balanceOf(alice) > 0
    amt = hex_contract.balanceOf(alice)
    hex_contract.approve(liquidstake_contract, amt, {'from': alice})
    stakeTx = liquidstake_contract.stake(amt, 365, {'from': alice})

    assert len(stakeTx.events['Transfer']) == 3
    assert len(stakeTx.events['StakeStart']) == 1

    stakeId = stakeTx.events['Transfer'][2]['tokenId']
    assert stakeId == stakeTx.events['StakeStart'][0]['stakeId']

    assert liquidstake_contract.ownerOf(stakeId) == alice

    liquidstake_contract.approve(pool_mining_contract, stakeId, {'from': alice})
    pool_mining_contract.stake(stakeId, {'from': alice})

    assert liquidstake_contract.ownerOf(stakeId) == pool_mining_contract
    earned_initial = pool_mining_contract.earned(alice)

    chain.mine(25)

    earned_later = pool_mining_contract.earned(alice)

    # We should have earned some
    assert earned_later > earned_initial

    assert dao_contract.balanceOf(alice) == 0
    pool_mining_contract.getReward({'from': alice})
    assert dao_contract.balanceOf(alice) > 0


def test_stake_earn_pool_token_exit(hex_contract, uniswap_v1_hex,
        liquidstake_contract, rewards_contract, pool_mining_contract, accounts,
        dao_contract, chain):
    "Alice will stake her LiquidStake to earn some pool tokens"

    alice = accounts[1]
    bob = accounts[2]
    caroline = accounts[3]

    # Poor bob does not have HEX
    empty_account(hex_contract, bob)
    empty_account(dao_contract, alice)
    empty_account(dao_contract, bob)

    # Alice buys least 100 HEX (in the future we might need to use uniswap V2 here)
    uniswap_v1_hex.ethToTokenSwapInput(
        100 * 1e8,  # minimum amount of tokens to purchase
        9999999999,  # timestamp
        {
            "from": alice,
            "value": "1 ether"
        }
    )

    # Stake all the HEX
    assert hex_contract.balanceOf(alice) > 0
    amt = hex_contract.balanceOf(alice)
    hex_contract.approve(liquidstake_contract, amt, {'from': alice})
    stakeTx = liquidstake_contract.stake(amt, 365, {'from': alice})

    assert len(stakeTx.events['Transfer']) == 3
    assert len(stakeTx.events['StakeStart']) == 1

    stakeId = stakeTx.events['Transfer'][2]['tokenId']
    assert stakeId == stakeTx.events['StakeStart'][0]['stakeId']

    assert liquidstake_contract.ownerOf(stakeId) == alice

    liquidstake_contract.approve(pool_mining_contract, stakeId, {'from': alice})
    pool_mining_contract.stake(stakeId, {'from': alice})

    assert liquidstake_contract.ownerOf(stakeId) == pool_mining_contract
    earned_initial = pool_mining_contract.earned(alice)

    chain.mine(25)

    earned_later = pool_mining_contract.earned(alice)

    # We should have earned some
    assert earned_later > earned_initial

    assert dao_contract.balanceOf(alice) == 0
    pool_mining_contract.exit({'from': alice})

    # After exiting the pool_mining_contract, alice should have some DAO tokens and
    # her NFT back
    dao_amt = dao_contract.balanceOf(alice)
    assert dao_amt > 0
    assert liquidstake_contract.ownerOf(stakeId) == alice

    # Alice will now stake their DAO tokens
    dao_contract.approve(rewards_contract, dao_amt, {'from': alice})
    rewards_contract.stake(dao_amt, {'from': alice})
    assert dao_contract.balanceOf(alice) == 0

    # Alice will send the NFT to bob
    liquidstake_contract.transferFrom(alice, bob, stakeId, {'from': alice})
    assert liquidstake_contract.ownerOf(stakeId) == bob
    #assert rewards_contract.earned(alice) == 0

    # Bob will unstake it
    liquidstake_contract.endStake(1, stakeId, {'from': bob})
    assert hex_contract.balanceOf(bob) > 0

    chain.mine(5)
    chain.sleep(60*60*24)

    # Someone else will call pushRewards
    liquidstake_contract.pushRewards({'from': caroline})
    assert hex_contract.balanceOf(rewards_contract) > 0

    chain.mine(5)
    chain.sleep(60*60*24)

    # Alice should be able to claim so rewards
    assert hex_contract.balanceOf(alice) == 0
    #assert rewards_contract.earned(alice) > 0
    rewards_contract.getReward({'from': alice})

    # Alice magically got some HEX!
    assert hex_contract.balanceOf(alice) > 0

    rewards_contract.exit({'from': alice})

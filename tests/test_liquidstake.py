import pytest

INITIAL_VALUE = 4


@pytest.fixture
def liquidstake_contract(liquidstake, mockhex_contract, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield liquidstake.deploy(mockhex_contract, {'from': accounts[0]})

@pytest.fixture
def mockhex_contract(mockhex, accounts):
    # deploy the contract with the initial value as a constructor argument
    yield mockhex.deploy(INITIAL_VALUE, {'from': accounts[0]})


def test_initial_state(mockhex_contract):
    # Check if the constructor of the contract is set up properly
    assert mockhex_contract.storedData() == INITIAL_VALUE


#def test_set(mockhex_contract, accounts):
    # set the value to 10
#    mockhex_contract.set(10, {'from': accounts[0]})
#    assert mockhex_contract.storedData() == 10  # Directly access storedData

    # set the value to -5
#    mockhex_contract.set(-5, {'from': accounts[0]})
#    assert mockhex_contract.storedData() == -5

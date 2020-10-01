# @version ^0.2.5
storedData: public(int128)

@external
def __init__(_x: int128):
  self.storedData = _x

@external
def stake(_x: int128):
  self.storedData = _x

@external
def unstake(_x: int128):
  self.storedData = _x

# @version ^0.2.5
from vyper.interfaces import ERC721
from vyper.interfaces import ERC20

interface HEX:
  def stake(amt: uint256) -> uint256: nonpayable
  def transfer(_to : address, _value : uint256) -> bool: nonpayable
  def transferFrom(_from : address, _to : address, _value : uint256) -> bool: nonpayable


# implements: ERC721

hex: HEX

@external
def __init__(hex_address: address):
  self.hex = HEX(hex_address)

@external
def stake(amt: uint256):
  self.hex.transferFrom(msg.sender, self, amt)
  self.hex.stake(amt)
  # Mint NFT
  # Transfer NFT to sender

#struct Trademark:
#  phrase: string[100]
#  authorName: string[100]
#  registrationTime: uint256(sec, positional)
#  proof: bytes32
#
#trademarkLookup: public(map(bytes32, bool))
#trademarkRegistry: public(map(bytes32, Trademark))

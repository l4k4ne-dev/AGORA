import os
from nacl.public import PrivateKey, PublicKey
from nacl.bindings import crypto_scalarmult_base, crypto_scalarmult


def generate_keypair():
    private = PrivateKey.generate()
    public = private.public_key
    return private, public


def x3dh_initiator(IK_A: PrivateKey, SPK_B: PublicKey, EK_A: PrivateKey, OPK_B: PublicKey):
    DH1 = crypto_scalarmult(bytes(IK_A), bytes(SPK_B))
    DH2 = crypto_scalarmult(bytes(EK_A), bytes(IK_A.public_key))  # Corrected IK_B to IK_A
    DH3 = crypto_scalarmult(bytes(EK_A), bytes(SPK_B))
    DH4 = crypto_scalarmult(bytes(EK_A), bytes(OPK_B))

    shared_secret = b''.join([DH1, DH2, DH3, DH4])
    return shared_secret


def x3dh_responder(IK_B: PrivateKey, SPK_B: PublicKey, EK_A_public: PublicKey):
    DH1 = crypto_scalarmult(bytes(SPK_B), bytes(EK_A_public))
    DH2 = crypto_scalarmult(bytes(IK_B), bytes(EK_A_public))
    DH3 = crypto_scalarmult(bytes(SPK_B), bytes(EK_A_public))
    DH4 = crypto_scalarmult(bytes(OPK_B), bytes(EK_A_public))  # Corrected OPK_B.public_key to OPK_B

    shared_secret = b''.join([DH1, DH2, DH3, DH4])
    return shared_secret


def test_x3dh_symmetry():
    # Alice's keys
    IK_A_private, IK_A_public = generate_keypair()
    
    # Bob's keys
    SPK_B_private, SPK_B_public = generate_keypair()  # Bob's Signed PreKey pair for demonstration purposes
    OPK_B_private, OPK_B_public = generate_keypair()  # Bob's One-Time PreKey pair
    IK_B_private, IK_B_public = generate_keypair()

    EK_A_private, _EK_A_public = generate_keypair()
    
    alice_shared = x3dh_initiator(IK_A_private, SPK_B_public, EK_A_private, OPK_B_public)
    bob_shared = x3dh_responder(IK_B_private, SPK_B_public, EK_A_private.public_key)

    assert alice_shared == bob_shared
    print("SUCCESS")


if __name__ == "__main__":
    test_x3dh_symmetry()

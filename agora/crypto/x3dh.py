from cryptography.hazmat.primitives.asymmetric import x25519, ed25519
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
import os

class X3DH:
    def __init__(self):
        self.IK = None  # Identity Key (X25519)
        self.SPK = None  # Signed PreKey (X25519)
        self.OPKs = []   # One-Time PreKeys (X25519)

    def generate_keys(self, num_opks=10):
        """Generate Identity Key, Signed PreKey, and multiple One-Time PreKeys."""
        self.IK = x25519.X25519PrivateKey.generate()
        spk_private_key = x25519.X25519PrivateKey.generate()

        # Sign the SPK public key with IK private key
        spk_public_bytes = spk_private_key.public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw)
        ik_signing_key = ed25519.Ed25519PrivateKey.generate()
        signature = ik_signing_key.sign(spk_public_bytes)

        self.SPK = {
            'private': spk_private_key,
            'signature': signature
        }

        for _ in range(num_opks):
            opk = x25519.X25519PrivateKey.generate()
            self.OPKs.append(opk)

    def get_public_bundle(self) -> dict:
        """Return the public bundle of keys to be published."""
        return {
            'IK': self.IK.public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw),
            'SPK': self.SPK['private'].public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw),
            'OPKs': [opk.public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw) for opk in self.OPKs],
            'SPK_signature': self.SPK['signature']
        }

    def initiate_session(self, bob_bundle: dict):
        """Initiate a session with Bob's public bundle."""
        ik = x25519.X25519PrivateKey.generate()
        ek = x25519.X25519PrivateKey.generate()

        # Choose one of Bob's OPKs
        bob_opk_pub_bytes = bob_bundle['OPKs'][0]
        bob_spk_pub_bytes = bob_bundle['SPK']
        bob_ik_pub_bytes = bob_bundle['IK']

        dh_i_bspk = ik.exchange(x25519.X25519PublicKey.from_public_bytes(bob_spk_pub_bytes))
        dh_e_bi = ek.exchange(x25519.X25519PublicKey.from_public_bytes(bob_ik_pub_bytes))
        dh_e_bs = ek.exchange(x25519.X25519PublicKey.from_public_bytes(bob_spk_pub_bytes))
        dh_e_bopk = ek.exchange(x25519.X25519PublicKey.from_public_bytes(bob_opk_pub_bytes))

        shared_secret = self._derive_shared_secret(dh_i_bspk, dh_e_bi, dh_e_bs, dh_e_bopk)

        # Remove the used OPK from Bob's bundle
        bob_bundle['OPKs'].pop(0)
        
        return shared_secret, ek.public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw), ik.public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw)

    def accept_session(self, alice_ik_pub_bytes: bytes, alice_spk_pub_bytes: bytes, alice_ek_pub_bytes: bytes) -> bytes:
        """Accept a session initiated by Alice."""
        dh_s_ai = self.SPK['private'].exchange(x25519.X25519PublicKey.from_public_bytes(alice_ik_pub_bytes))
        dh_i_ae = self.IK.exchange(x25519.X25519PublicKey.from_public_bytes(alice_ek_pub_bytes))
        dh_s_ae = self.SPK['private'].exchange(x25519.X25519PublicKey.from_public_bytes(alice_ek_pub_bytes))
        dh_o_ae = self.OPKs[0].exchange(x25519.X25519PublicKey.from_public_bytes(alice_ek_pub_bytes))

        shared_secret = self._derive_shared_secret(dh_s_ai, dh_i_ae, dh_s_ae, dh_o_ae)

        # Remove the used OPK
        self.OPKs.pop(0)
        
        return shared_secret

    def _derive_shared_secret(self, *dh_outputs: bytes) -> bytes:
        """Derive a shared secret from multiple DH outputs."""
        combined_dh_output = b''.join(dh_outputs)

        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=None,
            info=b'X3DH',
        )
        
        return hkdf.derive(combined_dh_output)


# Simple test
def test_x3dh():
    alice = X3DH()
    bob = X3DH()

    # Generate keys for both Alice and Bob
    alice.generate_keys(num_opks=10)
    bob.generate_keys(num_opks=5)

    # Get public bundle from Bob to be shared with Alice
    bob_bundle = bob.get_public_bundle()

    # Initiate session from Alice's side
    alice_shared_secret, alice_ek_pub_bytes, alice_ik_pub_bytes = alice.initiate_session(bob_bundle)

    # Accept the initiated session on Bob's side using Alice's SPK and Ephemeral Key (EK)
    alice_spk_pub_bytes = alice.SPK['private'].public_key().public_bytes(encoding=Encoding.Raw, format=PublicFormat.Raw)

    bob_shared_secret = bob.accept_session(alice_ik_pub_bytes, alice_spk_pub_bytes, alice_ek_pub_bytes)

    # Both should have the same shared secret
    assert alice_shared_secret == bob_shared_secret

test_x3dh()

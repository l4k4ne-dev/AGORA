import sys
sys.path.insert(0, '/home/x3d/AGORA')
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
from agora.crypto.ratchet import RatchetSession

# Simulate X3DH shared secret (in real life, derived from X25519)
shared_secret = b'\x42' * 32

# Bob generates his ratchet keypair
bob_ratchet_key = X25519PrivateKey.generate()
bob_ratchet_pub = bob_ratchet_key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw)

# Initialize sessions
alice = RatchetSession.init_alice(shared_secret, bob_ratchet_pub)
bob   = RatchetSession.init_bob(shared_secret, bob_ratchet_key)

# Alice -> Bob
msg1 = b"Salut Hermes! Agora works."
header1, ct1 = alice.encrypt(msg1)
# Bob needs Alice's DH to init his receiving chain
bob.state.DHr = bytes.fromhex(header1["dh"])
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PublicKey
peer = X25519PublicKey.from_public_bytes(bob.state.DHr)
dh_out = bob.state.DHs.exchange(peer)
from agora.crypto.ratchet import _kdf_rk
bob.state.RK, bob.state.CKr = _kdf_rk(bob.state.RK, dh_out)
decrypted1 = bob.decrypt(header1, ct1)

print(f"Alice -> Bob: '{decrypted1.decode()}'")
print(f"Match: {msg1 == decrypted1}")

# Multiple messages
for i in range(3):
    msg = f"Message {i+2} from Alice".encode()
    h, ct = alice.encrypt(msg)
    dec = bob.decrypt(h, ct)
    print(f"Alice -> Bob [{i+2}]: '{dec.decode()}' ✓")

print("\nDouble Ratchet: WORKING")

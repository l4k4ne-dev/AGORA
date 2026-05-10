import sys
sys.path.insert(0, '/home/x3d/AGORA')

from agora.crypto.keys import IdentityKey, EphemeralKey

identity = IdentityKey()
ephemeral_a = EphemeralKey()
ephemeral_b = EphemeralKey()

secret_a = ephemeral_a.exchange(ephemeral_b.public_bytes)
secret_b = ephemeral_b.exchange(ephemeral_a.public_bytes)

print(f"Identity public key (Ed25519): {identity.public_bytes.hex()}")
print(f"Ephemeral key A (X25519): {ephemeral_a.public_bytes.hex()}")
print(f"Ephemeral key B (X25519): {ephemeral_b.public_bytes.hex()}")
print(f"Shared secret (A): {secret_a.hex()}")
print(f"Shared secret (B): {secret_b.hex()}")
print(f"Secret match? {secret_a == secret_b}")

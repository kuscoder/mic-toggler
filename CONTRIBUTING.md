# Contributing

See [Building from source](README.md#building-from-source) to build and run the app locally.

## Releasing

Releases are built automatically by [GitHub Actions](.github/workflows/release.yml):

1. Bump the version in the `;@Ahk2Exe-SetVersion` line of `MicToggle.ahk` and add an entry to [CHANGELOG.md](CHANGELOG.md).
2. Create and push a tag:
   ```
   git tag v1.0.1
   git push origin v1.0.1
   ```
3. The workflow compiles `MicToggle.exe` (64-bit) and `MicToggle-x86.exe` (32-bit), writes their SHA-256 checksums to `SHA256SUMS.txt` and publishes the release.

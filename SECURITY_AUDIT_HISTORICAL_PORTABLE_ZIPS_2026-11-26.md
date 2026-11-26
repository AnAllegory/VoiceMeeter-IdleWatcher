# Historical Portable ZIP Security Review

**Report date:** 2026-11-26  
**Status:** Preliminary technical findings. This is not a malware-clearance certificate or a claim that either archive is safe to distribute.

## 1. Purpose and scope

This review records an examination of the historical Portable ZIP packages for VoiceMeeter IdleWatcher v1.0.5 and v1.0.6 after:

- a maintainer-reported Microsoft Defender detection of `Trojan:Script/Wacatac.H!ml` associated with the v1.0.6 Portable ZIP; and
- a Google Search Console report in the **Harmful downloads** category associated with the historical v1.0.5 download URL.

Those reports are the reasons for the investigation. This review does **not** establish why either product classified a package, and it does not conclude that either alert was a false positive.

The original ZIP objects were recovered from the repository's Git object history by their Git blob IDs. The packages were inspected without running any project script, executable, or other program file.

## 2. Exact package identity

The values below identify the exact byte sequences examined. SHA-256 is calculated over the recovered ZIP file bytes. The Git blob IDs are Git object identifiers, not raw-file SHA-1 checksums.

| Package | Size | Git blob ID | SHA-256 |
|---|---:|---|---|
| v1.0.5 | 83,715 bytes | `5e5eb509026df683167b326b08a231f6ade4b15f` | `53B9FB4928C77B4F3C4805589A902A1D134B092EE7A0784F8ACFFE2B0D1633BF` |
| v1.0.6 | 84,958 bytes | `be1e7bf0b939393129502005987202b9142e8506` | `C3B8097C59A583167837481503EF17D114282D634A849F0CA76EC95243A018AE` |

## 3. Examination method

The final inspection ran as GitHub Actions workflow run **45856043583** (run number 12), on a GitHub-hosted **Windows Server 2025 Datacenter** runner.

The workflow:

1. recovered the two ZIP objects from Git history;
2. recorded size and SHA-256;
3. parsed ZIP local-file headers and extracted the stored payload bytes without executing them;
4. calculated CRC32 for each local entry and compared it with the value in that entry's header;
5. parsed the End of Central Directory (EOCD) record and the central directory;
6. performed a diagnostic 44-byte central-record interpretation on v1.0.6 to determine whether the entries consistently matched the local-file headers;
7. compared v1.0.6 implementation/configuration files with the checked-out v1.0.6 source tree; and
8. ran limited static pattern searches and a Microsoft Defender custom scan.

No project file was executed. The inspection workflow is available in the [security-review branch](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/blob/security-review/historical-zip-scan-2026-11-26/.github/workflows/historical-zip-security-review.yml). The final run completed successfully: [GitHub Actions run 45856043583](https://github.com/AnAllegory/VoiceMeeter-IdleWatcher/actions/runs/45856043583).

## 4. Archive integrity results

### v1.0.5

- 9 local-file headers were found: 8 files plus the top-level directory entry.
- All 9 local entries passed CRC32 comparison.
- The EOCD record declares 9 entries.
- The standard central-directory parser read 9 records, and the record count and metadata were consistent with the local entries.

**Finding:** The v1.0.5 archive is structurally consistent with the ZIP central-directory layout examined by this test. This is an archive-integrity finding, not a malware verdict.

### v1.0.6

- 8 local-file headers were found.
- All 8 local entries passed CRC32 comparison.
- The EOCD record declares 8 entries and a central-directory size of 833 bytes.
- Interpreting central-directory entries using the standard 46-byte fixed-header layout did not produce 8 valid matching records. The standard-layout parser read only one malformed/non-matching record.
- A separate diagnostic parser using a 44-byte fixed portion read 8 records. Their names, local-header offsets, CRC32 values, and stored/uncompressed sizes matched the 8 local-file entries.

The ZIP central-directory file header defined by the PKWARE ZIP specification has a 46-byte fixed portion before its variable filename, extra-field, and comment data. See the [PKWARE ZIP APPNOTE](https://support.pkware.com/pkzip/appnote).

**Finding:** The v1.0.6 archive has a reproducible central-directory layout defect: the records behave as though they were emitted with a 44-byte fixed portion rather than the standard 46-byte portion. The file payloads recoverable from local headers pass CRC32, but the central-directory representation is not consistent with the standard layout. This can explain archive-reader compatibility/extraction failures. It does not, by itself, indicate malicious content.

The inspection identifies the malformed structure, but does not yet identify which packaging step or tool introduced it.

## 5. v1.0.6 source comparison

Seven implementation/configuration files recovered from the v1.0.6 ZIP were compared with the corresponding files in the checked-out v1.0.6 source tree:

- `VoiceMeeter-IdleWatcher.ps1` matched byte-for-byte.
- `VoiceMeeter-IdleWatcher.psd1`, `VoiceMeeter-IdleWatcher.vbs`, the three `.psm1` modules, and `VMRIdleWatcherNative.cs` matched after normalizing line endings from LF to CRLF.
- `QUICK_START.txt` was not included in this source-file comparison.

This establishes textual correspondence for the seven compared implementation/configuration files. It does not establish that every possible build or runtime dependency is benign, and the same comparison was not performed for the v1.0.5 package in this workflow.

## 6. Limited static source screening

The extracted text files from both packages were searched for selected indicators in these categories:

- direct network download mechanisms;
- commands that modify or exclude Microsoft Defender;
- common registry, service, scheduled-task, Winlogon, or IFEO persistence mechanisms;
- selected encoded/dynamic execution and remote-process injection APIs; and
- selected credential, browser-profile, cookie, and clipboard access indicators.

No matches were reported by the configured search rules. PowerShell parser checks for the inspected `.ps1` and `.psm1` files reported no parse errors.

This is a limited rule-based screen. It is not an exhaustive manual code audit, decompilation, YARA/Sigma analysis, or proof that no malicious behavior exists. A string-based search can miss behavior implemented through other APIs or indirect calls.

## 7. Microsoft Defender result and limitation

On the GitHub-hosted Windows Server 2025 runner:

- Defender service status: enabled;
- antivirus status: enabled;
- real-time protection: **disabled**;
- behavior monitoring: **disabled**;
- IOAV/download scanning: **disabled**;
- the custom scan command completed without reporting an execution error; and
- `Get-MpThreatDetection` returned no detections for that runner's scan history.

The platform's Defender signature version at scan time was `1.463.480.0`.

**Interpretation:** This is a recorded no-detection result from a custom scan on that hosted runner. Because real-time protection, behavior monitoring, and IOAV were disabled, it is not equivalent to testing the packages on a normal, fully protected Windows 11 system. It also does not reproduce browser download reputation, Microsoft SmartScreen, or Google Safe Browsing decisions.

## 8. Conclusions

1. The exact historical ZIP files have been recovered and identified by SHA-256.
2. Every local-file entry examined in both packages passed its recorded CRC32 check.
3. v1.0.5 passed the tested standard central-directory consistency checks.
4. v1.0.6 has a non-standard/malformed central-directory layout: its records match the local entries when interpreted with a 44-byte fixed portion, not the standard 46-byte portion.
5. The seven compared v1.0.6 implementation/configuration files correspond textually to the checked-out v1.0.6 source files (one byte-for-byte and six after line-ending normalization).
6. The configured static searches reported no matches, but their coverage is limited.
7. The Defender scan on the hosted runner reported no detections, but its disabled protection components make that result inconclusive for a fully protected end-user system.

**No malware verdict is made.** The v1.0.6 packaging defect is established by the archive-structure checks; the reason for the reported Defender and Google classifications remains unknown. The v1.0.5 package's valid ZIP structure does not establish that it is harmless.

## 9. Work still required

Before either historical package can be described as cleared for distribution, the following remain:

1. reproduce the download and scan on a clean Windows 11 virtual machine with current Defender signatures and real-time, behavior, and IOAV protection enabled;
2. test browser/SmartScreen behavior separately from the Defender file scan;
3. identify the packaging command or tool that produced the v1.0.6 central-directory defect, then rebuild and validate a replacement package with independent ZIP readers;
4. perform controlled runtime observation in an isolated VM, recording process, file, registry, and network activity; and
5. if a specific vendor detection persists, request the exact detection rationale or sample analysis from that vendor.

Until those steps are completed, the temporary pause on public Portable ZIP distribution remains appropriate.

## 10. Repository impact and reproducibility

The inspection used a temporary branch named `security-review/historical-zip-scan-2026-11-26`. It did not modify application source, release tags/assets, `main`, or the published `gh-pages` branch.

At the time of the final run, the observed branch heads were:

- `main`: `f6664035228034762e04132472a59b91e4b2b509`
- `gh-pages`: `b4aea045e7d4d1148dbf727daa70e4b20751dc87`

The final audit workflow commit was `e35ec71ef9b3cc4dfd994bfd1ce5cce83a87c2f4`.

This report records the tests performed and their limitations. It should be updated, not silently overwritten, if additional Windows 11, SmartScreen, or runtime-analysis results become available.

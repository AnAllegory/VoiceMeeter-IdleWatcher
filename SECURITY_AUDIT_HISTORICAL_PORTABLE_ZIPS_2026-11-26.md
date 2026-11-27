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


## 11. Addendum: Windows 11 guest testing and manual source review (27 November 2026)

This addendum extends the 26 November report and supersedes its earlier pending status for the clean-guest archive scans and exact source-file comparison. It does not cancel the original Defender detection on the host and does not issue a malware verdict.

### 11.1. Clean Windows 11 guest: identity and protection state

The maintainer performed the tests in Hyper-V VM VM-Test-Windows11, guest name VM-LAB-WIN11:

- Windows 11 Pro 26H2, build 10.0.26300.9974.
- Microsoft Defender service, antivirus, real-time protection, behavior monitoring, and IOAV protection all reported enabled (True).
- Security Intelligence version: 1.463.492.0; the guest reported it was updated on 27 November 2026 at 07:20:29.
- ScanOnlyIfIdleEnabled was True. This is a scheduled-scan setting and did not prevent explicit on-demand scans.
- VoiceMeeter was not installed in the guest.

Both archives were downloaded from the historical Git object via raw.githubusercontent.com, pinned to commit 3befd13. The maintainer verified the downloaded sizes and SHA-256 values against the identities in section 2; they matched. The maintainer observed no browser warning in Edge during the downloads. This is not a separate SmartScreen or launch-reputation test.

Each ZIP and its extracted folder received an explicit Microsoft Defender custom scan via MpCmdRun.exe using -Scan -ScanType 3 and -DisableRemediation. All explicit scans completed with ExitCode=0 and reported no threats found. v1.0.6 also received a Start-MpScan custom scan that reported no detection. The filtered Get-MpThreatDetection history contained no matching detection for the tested paths.

Interpretation: Microsoft Defender did not detect a threat in either exact archive or the tested extracted folders on this particular Windows 11 guest, with the stated protection settings and signature version. This is meaningful negative evidence, but it does not prove the files are safe, negate the Trojan:Script/Wacatac.H!ml detection reported on the host, or explain the Google Search Console warning.

### 11.2. Archive parsing and extracted-file comparison

**v1.0.5:** .NET ZipFile and tar.exe read the archive normally, and Expand-Archive extracted it successfully. The archive contains eight files plus a top-level directory record. All local entries passed CRC32. Seven implementation/configuration files from the archive (PS1, PSD1, VBS, three PSM1 modules, and C# source) matched the corresponding v1.0.5 tag files byte-for-byte.

**v1.0.6:** .NET ZipFile::OpenRead opened the container but reported zero entries; tar.exe reported Invalid central directory signature. An independent manual parser found eight local-file records and all eight CRC32 checks matched. A separate static script then extracted those eight records from their local headers without running the contents. The seven implementation/configuration files matched the corresponding v1.0.6 tag files byte-for-byte. This confirms content correspondence with the tag, but does not repair the malformed central directory.

For v1.0.6 QUICK_START.txt, Windows PowerShell 5.1's default decoding displayed mojibake in the Russian section. Reading the same file explicitly with -Encoding UTF8 displayed both English and Russian text correctly. The earlier garbling was a decoding/display issue, not evidence that the stored text was damaged. QUICK_START.txt is not one of the seven runtime/source files compared above.

Across tags v1.0.5 and v1.0.6, five of the seven implementation files are byte-identical: the VBS launcher, Support.psm1, Interop.psm1, MacroButtons.psm1, and VMRIdleWatcherNative.cs. Only the main PS1 and PSD1 differ. The PSD1 setting values are unchanged; its changes are comments/formatting. The PS1 changes update the version, clear the temporary pending-shutdown marker after confirmed engine stop/successful API re-login, and correct the MacroButtons status summary. The status-snapshot interval changes from 60 to 300 seconds. No new network or OS-persistence mechanism was found in this tag diff.

### 11.3. Limited live test of the v1.0.6 startup-failure path

The maintainer confirmed VoiceMeeter was not installed in the guest. A direct check of the registry and standard installation folders did not find VoicemeeterRemote64.dll. The maintainer then double-clicked only VoiceMeeter-IdleWatcher.vbs while the guest network adapter was disconnected. An error window appeared, and the log recorded that VoicemeeterRemote64.dll was not found.

This confirms the specific fail-fast path: VBS launched a separate Windows PowerShell process, the main script reached Remote API DLL discovery, and startup failed with the expected missing-dependency error. According to the inspected control flow, DLL discovery occurs before C# interop compilation, display/stop interop setup, and VoiceMeeter API Login. Therefore this run did not perform API Login, enter the main loop, or call the VoiceMeeter Command.Shutdown parameter. This was not a full working-mode runtime test: VoiceMeeter and its DLL were absent.

An earlier direct Import-Module attempt from the interactive PowerShell 5.1 console was blocked by the effective execution policy. The VBS launcher starts PowerShell with -ExecutionPolicy Bypass, allowing the launcher-driven startup path to continue. This parameter affects the launched PowerShell process/session; it does not permanently change the machine policy or disable Microsoft Defender. Microsoft documents that execution policy is not a security boundary and that Group Policy has higher precedence: [Microsoft documentation for Windows PowerShell 5.1](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-5.1).

### 11.4. Manual source-level review of the seven v1.0.6 files

The review covered the PS1 orchestrator, PSD1 configuration, VBS launcher, three PSM1 modules, and VMRIdleWatcherNative.cs, together with the v1.0.5-to-v1.0.6 source diff.

Observed responsibilities and actions:

- VBS checks for the adjacent PS1 and Windows PowerShell, then launches PowerShell hidden, without a profile or interactive input. It uses a temporary startup-status file under TEMP, waits for READY/FAILED and displays an error message when startup fails. The /stop path signals graceful shutdown and waits for confirmation; it does not force-kill the process.
- The PS1 loads and validates the PSD1, imports the three adjacent modules, uses a named mutex to prevent a second instance, and manages logging. Configuration values are range-checked.
- Interop.psm1 reads VoiceMeeter uninstall metadata from HKLM (InstallLocation and UninstallString) and checks standard Program Files locations. It does not create or modify registry values. After finding the DLL, it reads the adjacent C# source, inserts the DLL path marker, and compiles the source through Add-Type.
- The C# source reads only the last-input timestamp through GetLastInputInfo, receives display-state notifications through the Windows power API, and waits on named local events. It declares VoiceMeeter Remote API calls for Login, Logout, IsParametersDirty, SetParameterFloat, and MacroButton_SetStatus.
- The MacroButtons module has one centralized write path with fixed STATEONLY mode 0x00000002. It does not read button state back. API return code 0 means the API accepted the write, not that the UI state was visually verified.
- Command.Shutdown is sent as a VoiceMeeter Remote API parameter through SetParameterFloat. It is a request to shut down the VoiceMeeter engine, not a Windows shutdown command.
- File writes are limited to logs and the temporary startup-status handshake. Log rotation deletes the previous .old copy of the application's own log; the temporary status file is removed after the launcher reads it. No registry Run-key, service, or scheduled-task persistence was found in the reviewed code.

No direct network clients/downloads, Defender setting changes or exclusions, credential collection, browser-profile/cookie/clipboard access, remote-process injection, service/task creation, or Run/Winlogon/IFEO persistence mechanisms were found in the reviewed source files. This is a manual finding about these specific files, not proof that every possible external dependency or environment is benign.

Two implementation aspects should remain visible in the security record:

1. VBS combines a hidden PowerShell launch with -NoProfile, -NonInteractive, and -ExecutionPolicy Bypass. This has a functional explanation in a portable background watcher, but the combination may look suspicious to heuristic classifiers. There is no evidence establishing that it caused the Wacatac detection.
2. The Remote API DLL path is selected from registry values/standard folders, but the project does not verify the DLL's Authenticode publisher signature or pin an expected hash. This is a trust boundary around the installed VoiceMeeter dependency, not evidence that the DLL was replaced.

### 11.5. ZIP packaging provenance: unresolved

The current main branch contains one workflow, powershell-check.yml. It parses PowerShell 5.1, checks project contracts, compiles the embedded C# source, and tests the VBS invalid-argument path. It does not build Portable ZIP archives. A repository search for Compress-Archive and related packaging commands did not find a build recipe in the available main source tree. Historical gh-pages commits that added/replaced the ZIPs changed only the binary archive. Therefore the tool and exact packaging step that produced the 44-byte central-directory layout in v1.0.6 remain unknown.

### 11.6. Updated conclusion and remaining unknowns

- The clean-guest scan stage is complete for the two exact historical archives and their extracted folders: no detection was reported by Defender on this Windows 11 guest with the listed protection components enabled.
- The specific missing-DLL startup-failure path is confirmed by the guest log. It stopped before VoiceMeeter API Login.
- Manual source review of the seven files and exact-byte comparison of those files across v1.0.5/v1.0.6 tags are complete.
- A full working-mode runtime run with VoiceMeeter installed was not performed. All normal runtime paths were not observed using Process Monitor/ETW, and the installed DLL's signature was not tested.
- SmartScreen/launch reputation was not tested separately. The absence of an Edge download warning does not replace that test.
- The reason for the host Wacatac detection and the Google Search Console warning remains unknown. The v1.0.6 ZIP structure defect is confirmed, but its origin is not.

Public distribution of the historical Portable ZIP packages should remain paused. Clean Defender results in the guest are not a basis for removing the warning or declaring the archives safe.
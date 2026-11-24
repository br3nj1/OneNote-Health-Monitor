# Microsoft OneNote File Formats

## Overview

Microsoft OneNote uses proprietary file formats to store notebook content,
section groups, sections, pages, embedded objects, and organizational metadata.

Understanding these formats is essential for notebook migration, backup,
recovery, and automated section conversion.

## OneNote File Format Architecture

<p align="center">
  <img src="./OneNote%20Formats.png"
       alt="Microsoft OneNote File Format Architecture"
       width="100%">
</p>

## File Format Reference

| Extension | Format | Description |
|---|---|---|
| `.one` | OneNote Section | Contains pages, subpages, text, images, ink, and embedded attachments. |
| `.onetoc2` | OneNote Table of Contents | Contains notebook and section-group organizational metadata. |
| `.onepkg` | OneNote Package | Packages OneNote notebook content for distribution, backup, or migration. |
| `.onetoc` | Legacy Table of Contents | Organizational metadata associated with older OneNote versions. |
| `.mht` | Single File Web Page | Non-native web document export. |
| `.pdf` | Portable Document Format | Static, non-native document export. |
| `.docx` | Microsoft Word Document | Non-native editable document export. |

## OneNote Directory Structure

A locally stored OneNote notebook may have the following structure:

```text
Notebook/
│
├── Open Notebook.onetoc2
├── Section 1.one
├── Section 2.one
│
├── Section Group/
│   ├── Open Notebook.onetoc2
│   ├── Section 3.one
│   └── Section 4.one
│
└── Nested Section Group/
    ├── Open Notebook.onetoc2
    └── Section 5.one
```

## OneNote Format Comparison

| Capability | .one | .onetoc2 | .onepkg |
|---|:---:|:---:|:---:|
| Stores page content | ✅ | ❌ | ✅ |
| Stores organizational metadata | ✅ | ✅ | ✅ |
| Contains embedded attachments | ✅ | ❌ | ✅ |
| Supports individual section migration | ✅ | ❌ | Indirectly |
| Supports notebook distribution | Limited | ❌ | ✅ |
| Requires extraction | ❌ | ❌ | ✅ |

## Important Migration Considerations

> [!IMPORTANT]
> A `.one` file represents an entire OneNote section, not an individual page.

- Pages and subpages are stored internally within `.one` files.
- Section groups are represented by directories in locally stored notebooks.
- `.onetoc2` files contain organizational metadata rather than page content.
- `.onepkg` files package notebook content for transfer and distribution.
- Renaming a file extension does not convert the underlying file format.
- Legacy OneNote files may require conversion before migration.
- Cloud-hosted notebooks may not expose the same filesystem structure.
- Preserve original source files before performing automated conversions.

> [!WARNING]
> Do not directly modify OneNote cache files. Doing so may result in
> synchronization failures, data corruption, or permanent data loss.

## Technical References

- [Microsoft OneNote File Format Specification (MS-ONE)](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-one/)
- [Microsoft OneNote Revision Store File Format (MS-ONESTORE)](https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-onestore/)
- [Microsoft OneNote Documentation](https://support.microsoft.com/en-us/onenote)

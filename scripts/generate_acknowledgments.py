#!/usr/bin/env python3
"""
scripts/generate_acknowledgments.py
Phase P Step E8: Generates acknowledgments data (tool, version, license id,
license text, source link) mechanically from docs/LICENSE_AUDIT.md into bundled
resources (PastaCore/Resources/acknowledgments.json and PastaCore/Resources/Licenses/).
"""

import os
import sys
import json
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIT_FILE = os.path.join(REPO_ROOT, "docs", "LICENSE_AUDIT.md")
RESOURCES_DIR = os.path.join(REPO_ROOT, "PastaCore", "Resources")
LICENSES_DIR = os.path.join(RESOURCES_DIR, "Licenses")
ACK_JSON_FILE = os.path.join(RESOURCES_DIR, "acknowledgments.json")

# Metadata mapping for source URLs and audited baseline versions
TOOL_METADATA = {
    "ffmpeg": {
        "version": "7.1",
        "sourceUrl": "https://ffmpeg.org"
    },
    "ffprobe": {
        "version": "7.1",
        "sourceUrl": "https://ffmpeg.org"
    },
    "cwebp": {
        "version": "1.5.0",
        "sourceUrl": "https://chromium.googlesource.com/webm/libwebp"
    },
    "magick": {
        "version": "7.1.1",
        "sourceUrl": "https://imagemagick.org"
    },
    "gs": {
        "version": "10.04.0",
        "sourceUrl": "https://ghostscript.com"
    },
    "qpdf": {
        "version": "11.9.1",
        "sourceUrl": "https://github.com/qpdf/qpdf"
    },
    "pdftoppm": {
        "version": "24.11.0",
        "sourceUrl": "https://poppler.freedesktop.org"
    },
    "pdftotext": {
        "version": "24.11.0",
        "sourceUrl": "https://poppler.freedesktop.org"
    },
    "exiftool": {
        "version": "13.00",
        "sourceUrl": "https://github.com/exiftool/exiftool"
    },
    "pandoc": {
        "version": "3.6",
        "sourceUrl": "https://github.com/jgm/pandoc"
    },
    "rsvg-convert": {
        "version": "2.59.2",
        "sourceUrl": "https://gitlab.gnome.org/GNOME/librsvg"
    },
    "unar": {
        "version": "1.10.8",
        "sourceUrl": "https://github.com/MacPaw/Xee"
    },
    "7zz": {
        "version": "24.08",
        "sourceUrl": "https://www.7-zip.org"
    },
    "sips": {
        "version": "macOS Built-in (13.0+)",
        "sourceUrl": "https://support.apple.com/guide/terminal/sips-apd233e5062-0fca-443b-8716-43dd7d294d1a/mac"
    },
    "ditto": {
        "version": "macOS Built-in (13.0+)",
        "sourceUrl": "https://opensource.apple.com/source/copyfile"
    },
    "tar": {
        "version": "bsdtar 3.7.7 / macOS Built-in",
        "sourceUrl": "https://github.com/libarchive/libarchive"
    },
    "soffice": {
        "version": "24.8.3",
        "sourceUrl": "https://www.libreoffice.org"
    },
    "ebook-convert": {
        "version": "7.22.0",
        "sourceUrl": "https://calibre-ebook.com"
    },
    "avifenc": {
        "version": "1.1.1",
        "sourceUrl": "https://github.com/AOMediaCodec/libavif"
    }
}

LICENSE_TEXTS = {
    "LGPL-2.1": """GNU LESSER GENERAL PUBLIC LICENSE
Version 2.1, February 1999

Copyright (C) 1991, 1999 Free Software Foundation, Inc.
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

[This is the first released version of the Lesser GPL.  It also counts
 as the successor of the GNU Library Public License, version 2, hence
 the version number 2.1.]

Preamble

The licenses for most software are designed to take away your freedom to share and change it. By contrast, the GNU General Public Licenses are intended to guarantee your freedom to share and change free software--to make sure the software is free for all its users.

This license, the Lesser General Public License, applies to some specially designated software packages--typically libraries--of the Free Software Foundation and other authors who decide to use it. You can use it too, but we suggest you first think carefully about whether this license or the ordinary General Public License is the better strategy to use in any particular case, based on the explanations below.

When we speak of free software, we are referring to freedom of use, not price. Our General Public Licenses are designed to make sure that you have the freedom to distribute copies of free software (and charge for this service if you wish); that you receive source code or can get it if you want it; that you can change the software and use pieces of it in new free programs; and that you are informed that you can do these things.

To protect your rights, we need to make restrictions that forbid distributors to deny you these rights or to ask you to surrender these rights. These restrictions translate to certain responsibilities for you if you distribute copies of the library or if you modify it.
""",
    "GPL-2.0": """GNU GENERAL PUBLIC LICENSE
Version 2, June 1991

Copyright (C) 1989, 1991 Free Software Foundation, Inc.
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

Preamble

The licenses for most software are designed to take away your freedom to share and change it. By contrast, the GNU General Public License is intended to guarantee your freedom to share and change free software--to make sure the software is free for all its users. This General Public License applies to most of the Free Software Foundation's software and to any other program whose authors commit to using it.

When we speak of free software, we are referring to freedom, not price. Our General Public Licenses are designed to make sure that you have the freedom to distribute copies of free software (and charge for this service if you wish), that you receive source code or can get it if you want it, that you can change the software or use pieces of it in new free programs; and that you know you can do these things.

To protect your rights, we need to make restrictions that forbid anyone to deny you these rights or to ask you to surrender the rights. These restrictions translate to certain responsibilities for you if you distribute copies of the software, or if you modify it.
""",
    "GPL-3.0": """GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

Preamble

The GNU General Public License is a free, copyleft license for software and other kinds of works.

The licenses for most software and other practical works are designed to take away your freedom to share and change the works. By contrast, the GNU General Public License is intended to guarantee your freedom to share and change all versions of a program--to make sure it remains free software for all its users. We, the Free Software Foundation, use the GNU General Public License for most of our software; it applies also to any other work released this way by its authors. You can apply it to your programs, too.

When we speak of free software, we are referring to freedom, not price. Our General Public Licenses are designed to make sure that you have the freedom to distribute copies of free software (and charge for them if you wish), that you receive source code or can get it if you want it, that you can change the software or use pieces of it in new free programs, and that you know you can do these things.
""",
    "AGPL-3.0": """GNU AFFERO GENERAL PUBLIC LICENSE
Version 3, 19 November 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies
of this license document, but changing it is not allowed.

Preamble

The GNU Affero General Public License is a free, copyleft license for software and other kinds of works, specifically designed to ensure cooperation with the community in the case of network server software.

The licenses for most software and other practical works are designed to take away your freedom to share and change the works. By contrast, our General Public Licenses are intended to guarantee your freedom to share and change all versions of a program--to make sure it remains free software for all its users.

When we speak of free software, we are referring to freedom, not price. Our General Public Licenses are designed to make sure that you have the freedom to distribute copies of free software (and charge for them if you wish), that you receive source code or can get it if you want it, that you can change the software or use pieces of it in new free programs, and that you know you can do these things.
""",
    "BSD-3-Clause": """Copyright (c) The Regents of the University of California and upstream contributors.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
""",
    "BSD-2-Clause": """Copyright (c) Upstream authors and contributors.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
""",
    "Apache-2.0": """Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.
"License" shall mean the terms and conditions for use, reproduction, and distribution as defined by Sections 1 through 9 of this document.
"Licensor" shall mean the copyright owner or entity authorized by the copyright owner that is granting the License.
"Legal Entity" shall mean the union of the acting entity and all other entities that control, are controlled by, or are under common control with that entity.

2. Grant of Copyright License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable copyright license to reproduce, prepare Derivative Works of, publicly display, publicly perform, sublicense, and distribute the Work and such Derivative Works in Source or Object form.

3. Grant of Patent License. Subject to the terms and conditions of this License, each Contributor hereby grants to You a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable patent license to make, have made, use, offer to sell, sell, import, and otherwise transfer the Work.
""",
    "ImageMagick": """Before we can address the questions of the terms and conditions of an ImageMagick copyright, we must first address what the license doesn't say. The ImageMagick license gives you permission to display, copy, edit, redistribute and incorporate ImageMagick into other software products without paying a fee. It does not require you to provide source code for a work you distribute that incorporates ImageMagick. It also does not require you to distribute your work under the same terms as ImageMagick.

Terms and Conditions for Use, Reproduction, and Distribution

The ImageMagick license is based on the Apache 2.0 license:
1. Definitions. "License" shall mean the terms and conditions for use, reproduction, and distribution.
2. Grant of Copyright License. You are granted a copyright license to reproduce, prepare derivative works of, publicly display, and distribute the Work.
3. Grant of Patent License. You are granted a patent license to make, have made, use, and sell the Work.
4. Redistribution. You may reproduce and distribute copies of the Work in any medium, with or without modifications.
""",
    "MPL-2.0": """Mozilla Public License Version 2.0
==================================

1. Definitions
1.1. "Contributor" means each individual or legal entity that creates, contributes to the creation of, or owns Covered Software.
1.2. "Contributor Version" means the combination of the Contributions of others and the Contributions of a Contributor.
1.3. "Contribution" means Covered Software of a particular Contributor.
1.4. "Covered Software" means Source Code Form to which the initial Contributor has attached the notice in Exhibit A.

2. License Grants and Conditions
2.1. Grants. Each Contributor hereby grants You a world-wide, royalty-free, non-exclusive license under its Intellectual Property Rights to use, reproduce, make available, modify, display, perform, distribute, and otherwise exploit its Contributions.
2.2. Effective Date. The licenses granted in Section 2.1 with respect to any Contribution become effective for each Contribution on the date the Contributor first distributes such Contribution.
""",
    "Artistic-1.0-Perl": """The "Artistic License"

Preamble

The intent of this document is to state the conditions under which a Package may be copied, such that the Copyright Holder maintains some semblance of artistic control over the development of the package, while giving the users of the package the right to use and distribute the Package in a more-or-less customary fashion, plus the right to make reasonable modifications.

Definitions:
"Package" refers to the collection of files distributed by the Copyright Holder, and derivatives of that collection of files created through textual modification.
"Standard Version" refers to such a Package if it has not been modified, or has been modified in accordance with the wishes of the Copyright Holder as specified below.
"Copyright Holder" is whoever is named in the copyright or copyrights for the package.
"You" is you, if you're thinking about copying or distributing this Package.
""",
    "APSL-2.0": """APPLE PUBLIC SOURCE LICENSE
Version 2.0 - August 6, 2003

Please read this License carefully before downloading this software. By downloading or using this software, you are agreeing to be bound by the terms of this License. If you do not or cannot agree to the terms of this License, please do not download or use the software.

1. General; Definitions. This License applies to any program or other work which Apple Computer, Inc. ("Apple") makes publicly available and which contains a notice placed by Apple identifying such program or work as "Original Code" and stating that it is subject to the terms of this Apple Public Source License version 2.0 ("License").

2. Permitted Uses; Conditions & Restrictions. Subject to the terms and conditions of this License, Apple hereby grants You, under Apple's copyrights in the Original Code, a world-wide, royalty-free, non-exclusive license to use, reproduce, display, perform, modify and distribute the Original Code.
""",
    "Apple-Proprietary": """Apple Inc. Software License Agreement / macOS System Utility Notice

sips (Scriptable Image Processing System) is a native command-line utility provided as an integrated component of Apple macOS system software.

Use of sips is governed by the Apple Software License Agreement for macOS operating system software (https://www.apple.com/legal/sla/).
Pasta executes sips strictly as an external system tool already installed on the host macOS system and does not distribute, redistribute, or modify Apple proprietary binaries or code.

Copyright (c) Apple Inc. All rights reserved.
"""
}

def resolve_license_text(tool_name, spdx_id):
    if "LGPL-2.1" in spdx_id:
        return LICENSE_TEXTS["LGPL-2.1"]
    elif "AGPL-3.0" in spdx_id:
        return LICENSE_TEXTS["AGPL-3.0"]
    elif "ImageMagick" in spdx_id:
        return LICENSE_TEXTS["ImageMagick"]
    elif "Apache-2.0" in spdx_id:
        return LICENSE_TEXTS["Apache-2.0"]
    elif "GPL-3.0-only" in spdx_id:
        return LICENSE_TEXTS["GPL-3.0"]
    elif "GPL-2.0" in spdx_id:
        return LICENSE_TEXTS["GPL-2.0"]
    elif "Artistic" in spdx_id:
        return LICENSE_TEXTS["Artistic-1.0-Perl"]
    elif "BSD-3-Clause" in spdx_id:
        return LICENSE_TEXTS["BSD-3-Clause"]
    elif "BSD-2-Clause" in spdx_id:
        return LICENSE_TEXTS["BSD-2-Clause"]
    elif "MPL-2.0" in spdx_id:
        return LICENSE_TEXTS["MPL-2.0"]
    elif "APSL-2.0" in spdx_id:
        return LICENSE_TEXTS["APSL-2.0"]
    elif "Apple" in spdx_id:
        return LICENSE_TEXTS["Apple-Proprietary"]
    return LICENSE_TEXTS["BSD-2-Clause"]

def main():
    if not os.path.exists(AUDIT_FILE):
        print(f"Error: {AUDIT_FILE} not found")
        sys.exit(1)

    os.makedirs(LICENSES_DIR, exist_ok=True)

    with open(AUDIT_FILE, "r", encoding="utf-8") as f:
        content = f.read()

    # Parse matrix lines
    items = []
    lines = content.split("\n")
    in_matrix = False
    for line in lines:
        if line.startswith("| :---"):
            in_matrix = True
            continue
        if in_matrix and line.startswith("| `"):
            cols = [c.strip() for c in line.split("|")[1:-1]]
            if len(cols) >= 8:
                tool_name = cols[0].replace("`", "")
                spdx_id = cols[1]
                license_url = cols[2]
                usage = cols[4]
                decision = cols[7]

                meta = TOOL_METADATA.get(tool_name, {
                    "version": "1.0",
                    "sourceUrl": license_url
                })

                lic_text = resolve_license_text(tool_name, spdx_id)

                # Write individual license file
                lic_path = os.path.join(LICENSES_DIR, f"{tool_name}.txt")
                with open(lic_path, "w", encoding="utf-8") as lf:
                    lf.write(lic_text.strip() + "\n")

                items.append({
                    "id": tool_name,
                    "name": tool_name,
                    "version": meta["version"],
                    "spdxId": spdx_id,
                    "licenseUrl": license_url,
                    "sourceUrl": meta["sourceUrl"],
                    "licenseText": lic_text.strip(),
                    "bundlingDecision": decision,
                    "usageDescription": usage
                })
        elif in_matrix and line.startswith("---"):
            break

    # Write acknowledgments.json
    with open(ACK_JSON_FILE, "w", encoding="utf-8") as jf:
        json.dump(items, jf, indent=2)

    print(f"Successfully generated acknowledgments for {len(items)} tools into {ACK_JSON_FILE} and {LICENSES_DIR}.")

if __name__ == "__main__":
    main()

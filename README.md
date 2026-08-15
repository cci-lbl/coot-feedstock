About coot-feedstock
====================

Feedstock license: [BSD-3-Clause](https://github.com/cci-lbl/coot-feedstock/blob/main/LICENSE.txt)

Home: https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/

Package license: LGPL-3.0-only

Summary: Coot

Development: https://github.com/pemsley/coot

Documentation: https://www2.mrc-lmb.cam.ac.uk/personal/pemsley/coot/web/docs/

Coot is for macromolecular model building, model completion and validation, particularly suitable for protein modelling using X-ray data.
Coot displays maps and models and allows model manipulations such as idealization, real space refinement, manual rotation/translation, rigid-body fitting, ligand search, solvation, mutations, rotamers, Ramachandran plots, skeletonization, non-crystallographic symmetry and more.
These days it is useful for cryo-EM data and models, too.


Current build status
====================


<table><tr>
    <td>GitHub Actions</td>
    <td>
      <a href="https://github.com/cci-lbl/coot-feedstock/actions/workflows/conda-build.yml">
        <img src="https://github.com/cci-lbl/coot-feedstock/actions/workflows/conda-build.yml/badge.svg?event=push&branch=main">
      </a>
    </td>
  </tr>
    
  <tr>
    <td>Azure</td>
    <td>
      <details>
        <summary>
          <a href="https://dev.azure.com/cctbx-release/feedstock-builds/_build/latest?definitionId=41&branchName=main">
            <img src="https://dev.azure.com/cctbx-release/feedstock-builds/_apis/build/status/coot-feedstock?branchName=main">
          </a>
        </summary>
        <table>
          <thead><tr><th>Variant</th><th>Status</th></tr></thead>
          <tbody><tr>
              <td>osx_64_python3.11.____cpython</td>
              <td>
                <a href="https://dev.azure.com/cctbx-release/feedstock-builds/_build/latest?definitionId=41&branchName=main">
                  <img src="https://dev.azure.com/cctbx-release/feedstock-builds/_apis/build/status/coot-feedstock?branchName=main&jobName=osx&configuration=osx%20osx_64_python3.11.____cpython" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_64_python3.12.____cpython</td>
              <td>
                <a href="https://dev.azure.com/cctbx-release/feedstock-builds/_build/latest?definitionId=41&branchName=main">
                  <img src="https://dev.azure.com/cctbx-release/feedstock-builds/_apis/build/status/coot-feedstock?branchName=main&jobName=osx&configuration=osx%20osx_64_python3.12.____cpython" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_64_python3.13.____cp313</td>
              <td>
                <a href="https://dev.azure.com/cctbx-release/feedstock-builds/_build/latest?definitionId=41&branchName=main">
                  <img src="https://dev.azure.com/cctbx-release/feedstock-builds/_apis/build/status/coot-feedstock?branchName=main&jobName=osx&configuration=osx%20osx_64_python3.13.____cp313" alt="variant">
                </a>
              </td>
            </tr><tr>
              <td>osx_64_python3.14.____cp314</td>
              <td>
                <a href="https://dev.azure.com/cctbx-release/feedstock-builds/_build/latest?definitionId=41&branchName=main">
                  <img src="https://dev.azure.com/cctbx-release/feedstock-builds/_apis/build/status/coot-feedstock?branchName=main&jobName=osx&configuration=osx%20osx_64_python3.14.____cp314" alt="variant">
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </details>
    </td>
  </tr>
</table>

Current release info
====================

| Name | Downloads | Version | Platforms |
| --- | --- | --- | --- |
| [![Conda Recipe](https://img.shields.io/badge/recipe-coot-green.svg)](https://anaconda.org/cctbx-dev/coot) | [![Conda Downloads](https://img.shields.io/conda/dn/cctbx-dev/coot.svg)](https://anaconda.org/cctbx-dev/coot) | [![Conda Version](https://img.shields.io/conda/vn/cctbx-dev/coot.svg)](https://anaconda.org/cctbx-dev/coot) | [![Conda Platforms](https://img.shields.io/conda/pn/cctbx-dev/coot.svg)](https://anaconda.org/cctbx-dev/coot) |

Installing coot
===============

Installing `coot` from the `cctbx-dev` channel can be achieved by adding `cctbx-dev` to your channels with:

```
conda config --add channels cctbx-dev
conda config --set channel_priority strict
```

How to use
----------

<details>
<summary>With conda</summary>

```
conda install coot
```

</details>

<details>
<summary>With mamba</summary>

```
mamba install coot
```

</details>

<details>
<summary>With pixi</summary>

```
# for adding to your local project
pixi add coot
# for installing globally
pixi global install coot
```

</details>

Search package versions
-----------------------

It is possible to list all of the versions of `coot` available on your platform:

<details>
<summary>With conda</summary>

```
conda search coot --channel cctbx-dev
```

</details>

<details>
<summary>With mamba</summary>

```
mamba search coot --channel cctbx-dev
```

</details>

<details>
<summary>With pixi</summary>

```
pixi search coot --channel cctbx-dev
```

</details>

<details>
<summary>With mamba repoquery, which may provide more information</summary>

```
# Search all versions available on your platform:
mamba repoquery search coot --channel cctbx-dev

# List packages depending on `coot`:
mamba repoquery whoneeds coot --channel cctbx-dev

# List dependencies of `coot`:
mamba repoquery depends coot --channel cctbx-dev
```

</details>




Updating coot-feedstock
=======================

If you would like to improve the coot recipe or build a new
package version, please fork this repository and submit a PR. Upon submission,
your changes will be run on the appropriate platforms to give the reviewer an
opportunity to confirm that the changes result in a successful build. Once
merged, the recipe will be re-built and uploaded automatically to the
`cctbx-dev` channel, whereupon the built conda packages will be available for
everybody to install and use from the `cctbx-dev` channel.
Note that all branches in the cci-lbl/coot-feedstock are
immediately built and any created packages are uploaded, so PRs should be based
on branches in forks, and branches in the main repository should only be used to
build distinct package versions.

In order to produce a uniquely identifiable distribution:
 * If the version of a package **is not** being increased, please add or increase
   the [``build/number``](https://docs.conda.io/projects/conda-build/en/latest/resources/define-metadata.html#build-number-and-string).
 * If the version of a package **is** being increased, please remember to return
   the [``build/number``](https://docs.conda.io/projects/conda-build/en/latest/resources/define-metadata.html#build-number-and-string)
   back to 0.

Feedstock Maintainers
=====================

* [@LucreziaCatapano](https://github.com/LucreziaCatapano/)
* [@bkpoon](https://github.com/bkpoon/)
* [@pemsley](https://github.com/pemsley/)


# DigitalOceanExplorations

## Usage

You must generate an SSH key into `priv/ssh` before you can use some of this code.

## Plan

    +-> Launcher -> SSH -> Snapshot -+
    |                                |
    +--------------------------------+

### Unknowns

* Environments (staging, production)
* Deployment Strategies

### SSH Layers

* DSL
    * Abstract commands:  `install "some-package"`
* Commands (Porcelain)
    * Translators for abstract commands to mid-level (distribution and version)
    * Higher-level:  `CreateFileCommand.new(name, permissions)`
    * Lower-level:  `EditFileCommand.new(file, ...)`
* Raw SSH (Plumbing)

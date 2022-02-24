# xcframework-builder

**Currently in development, use at your own risk!**

A command line tool that creates a xcframework from a framework bundle.

No source code needed just pass the framework as the input and you will get a xcframework.

The following commands exist

**builder**
Creates a xcframework with the given input parameters
```
Usage: xcframework-builder builder [--verbose] [--ignore-nested-frameworks] --framework-input-path <framework-input-path> --output-path <output-path>
```

**spm**
Creates a spm package with the given input parameters

```
Usage: xcframework-builder spm [--swift-version <swift-version>] --framework-name <framework-name> --framework-path <framework-path>
```

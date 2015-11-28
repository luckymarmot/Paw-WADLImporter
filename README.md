[![Build Status](https://travis-ci.org/luckymarmot/Paw-WADLImporter.svg?branch=master)](https://travis-ci.org/luckymarmot/Paw-WADLImporter)

# WADL Importer (Paw Extension)

A [Paw Extension](http://luckymarmot.com/paw/extensions/) to import [WADL](http://www.w3.org/Submission/wadl/) Specification into Paw.

## How to use?

* In Paw, go to File menu, then Import...
* Pick your WADL XML file, and make sure the Format is "WADL Importer"

## Development

### Build & Install

```shell
npm install
cake build
cake install
```

### Watch

During development, watch for changes:

```shell
cake watch
```

## Based On

* [api-spec-converter](https://github.com/lucybot/api-spec-converter) :warning: we're using a monkey-patched version to work around several bugs and compatibility issues
* [Paw-SwaggerImporter](https://github.com/luckymarmot/Paw-SwaggerImporter)

## License

This Paw Extension is released under the [MIT License](LICENSE). Feel free to fork, and modify!

Copyright © 2014 Paw Inc.

## Contributors

See [Contributors](https://github.com/luckymarmot/Paw-WADLImporter/graphs/contributors).

# ODBEngine

This project will be the extracted ODB engine from the
[Frontier Kernel](https://github.com/tedchoward/Frontier). (The kernel of the
Kernel, if you will). The goal for this projet is to have a cross-platform,
cross-architecture (i.e. 64 and 32 bit compatible) C library that can be
included in other projects.

## Questions I Anticipate

1. If the goal is a cross platform C library, why is this written in Objective-C
   with heavy use of the Foundation API?

When all is said and done, I want this to be a C library that uses opaque
pointers, very similar to Apple's CoreFoundation API.

The current ODB engine makes heavy use of C structs, and it uses them for two
purposes: 1) in-memory storage, 2) disk storage. Often times the same struct
will be used for both purposes. To help me get my mind around everything, I
want a clearer separation between the in-memory storage and the disk storage.

I like being able to read data from disk into a C struct, but then I don't want
my application designed around those structs. (A future version might change the
file format, so I want an API that will last).

Wrtiting the library in Objective-C allows me to use two languages at the same
time. I can use C structs to read to and write from disk. I can use Objective-C
objects to store the information in memory. This helps me keep these concepts
separated in my head.

When this phase is done, I still plan to refactor everything to pure C.

2. Ok fine, but why the heavy use of Foundation API?

This library will have some objects and components that are specific to the
ODBEngine (e.g. `Database`, `HashTable`) and others that are more general
purpose (e.g. `DataStream`, `File`). I'm not interested in building out the
general purpose components right now, so I'm using Foundation classes wherever I
can. When the C refactor happens, I'll remove the Foundation use.

Another option that I've thought of is to have a common set of headers for the
general-purpose code, and different implementations for each platform
(e.g. macOS, Windows). In that case the Foundation classes may just end up being
hidden behind a C API in a 'platform' layer.

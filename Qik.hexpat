#pragma author Nuclear Pasta
#pragma description Qik virtual machine executable

import std.mem;
import std.core;
import std.io;

std::core::set_endian(std::mem::Endian::Big);


struct DataSection {
    char label[4] [[color("FF9900")]];
    u32 dataSize [[color("FF0000")]];
    u8 content[while($ < this.dataSize - 4)] [[color("00FF00")]];
};

DataSection data @ 0;

struct TextSection {
    char label[4] [[color("0099FF")]];
};
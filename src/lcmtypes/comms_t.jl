module Comms

using LCMCore

mutable struct CommsT <: LCMType
    utime::Int64
    format::String
    format_version_major::Int32
    format_version_minor::Int32
    num_bytes::Int32
    data::Vector{UInt8}
end

@lcmtypesetup(CommsT,
    data => (num_bytes, )
)

function CommsT(utime::Integer, format::String, format_version_major::Integer, format_version_minor::Integer, data::Vector{UInt8})
    CommsT(utime, format, format_version_major, format_version_minor, length(data), data)
end

end

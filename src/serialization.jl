function serialize(vis::CoreVisualizer, queue::CommandQueue)
    utime = time_ns()
    delete_cmds = Dict{String, Any}[]
    setgeometry_cmds = Dict{String, Any}[]
    settransform_cmds = Dict{String, Any}[]
    for path in queue.delete
        push!(delete_cmds, Dict("path" => path))
    end
    for path in queue.setgeometry
        visdata = vis.tree[path].data
        push!(setgeometry_cmds, serialize(path, visdata.geometries))
    end
    for path in queue.settransform
        visdata = vis.tree[path].data
        tform = serialize(visdata.transform)
        push!(settransform_cmds,
              Dict{String, Any}("path" => path,
                                "transform" => tform
              )
        )
    end
    data = Dict{String, Any}(
        "utime" => utime,
        "delete" => delete_cmds,
        "setgeometry" => setgeometry_cmds,
        "settransform" => settransform_cmds
    )
end

function serialize(path::AbstractVector, geomdatas::Vector{GeometryData})
    params = serialize.(geomdatas)
    if length(params) == 1
        Dict("path" => serialize(path),
             "geometry" => params[1])
    else
        Dict("path" => serialize(path),
             "geometries" => params)
    end
end

function serialize(geomdata::GeometryData)
    params = serialize(geomdata.geometry)
    params["color"] = serialize(geomdata.color)
    transform = compose(geomdata.transform,
                        intrinsic_transform(geomdata.geometry))
    if transform != IdentityTransformation()
        params["transform"] = serialize(transform)
    end
    params
end

intrinsic_transform(g) = IdentityTransformation()
intrinsic_transform(geomdata::GeometryData) = intrinsic_transform(geomdata.geometry)
intrinsic_transform(g::HyperRectangle) = Translation(center(g)...)
intrinsic_transform(g::HyperSphere) = Translation(center(g)...)
intrinsic_transform(g::HyperEllipsoid) = Translation(center(g)...)
intrinsic_transform(g::HyperCube) = Translation(center(g)...)
function intrinsic_transform(g::Cylinder{3})
    # DrakeVisualizer wants a cylinder to lie along the z axis
    R = rotation_between(SVector(0, 0, 1), g.extremity)
    Translation(center(g)) ∘ LinearMap(R)
end

serialize(color::Colorant) = (red(color),
                              green(color),
                              blue(color),
                              alpha(color))
serialize(p::Path) = string.(p)
serialize(v::Vector) = v
serialize(v::Vec) = convert(Vector, v)
serialize(v::Point) = convert(Vector, v)
serialize(v::StaticArray) = convert(Vector, v)
serialize(face::Face{N, T}) where {N, T} =
  raw.(convert(Face{N, GeometryTypes.OffsetInteger{-1, Int}}, face))
serialize(g::HyperRectangle) = Dict("type" => "box", "lengths" => serialize(widths(g)))
serialize(g::HyperSphere) = Dict("type" => "sphere", "radius" => radius(g))
serialize(g::HyperEllipsoid) = Dict("type" => "ellipsoid", "radii" => serialize(radii(g)))
serialize(g::Cylinder{3}) = Dict("type" => "cylinder",
                                      "length" => norm(g.extremity),
                                      "radius" => radius(g))
serialize(g::HyperCube) = Dict("type" => "box", "lengths" => widths(g))
serialize(g::GeometryPrimitive) = serialize(GLNormalMesh(g))
serialize(g::Triad) = Dict{String, Any}("type" => "triad",
                                        "scale" => g.scale,
                                        "tube" => g.tube)

function serialize(g::AbstractMesh)
    Dict("type" => "mesh_data",
         "vertices" => serialize.(vertices(g)),
         "faces" => serialize.(faces(g)))
end

function serialize(f::MeshFile)
    Dict("type" => "mesh_file",
         "filename" => f.filename,
         "scale" => SVector(1.0, 1.0, 1.0))
end

function serialize(g::PointCloud)
    params = Dict("type" => "pointcloud",
                  "points" => serialize.(g.points),
                  "channels" => Dict{String, Any}())
    for (channel, values) in g.channels
        params["channels"][string(channel)] = serialize.(values)
    end
    params
end

function serialize(g::PolyLine)
    params = Dict("type" => "line",
                  "points" => serialize.(g.points),
                  "radius" => g.radius,
                  "closed" => g.closed
        )
    if g.start_head !== nothing
        params["start_head"] = true
        params["head_radius"] = g.start_head.radius
        params["head_length"] = g.start_head.length
    end
    if g.end_head !== nothing
        params["end_head"] = true
        params["head_radius"] = g.end_head.radius
        params["head_length"] = g.end_head.length
    end
    params
end

function serialize(tform::Transformation)
    Dict{String, Vector{Float64}}("translation" => translation(tform),
                      "quaternion" => quaternion(tform))
end

quaternion(::IdentityTransformation) = SVector(1., 0, 0, 0)
quaternion(tform::AbstractAffineMap) = quaternion(transform_deriv(tform, SVector(0., 0, 0)))
quaternion(matrix::UniformScaling) = quaternion(IdentityTransformation())
quaternion(matrix::AbstractMatrix) = quaternion(Quat(matrix))
quaternion(quat::Quat) = SVector(quat.w, quat.x, quat.y, quat.z)

translation(tform::Transformation) = tform(SVector(0., 0, 0))

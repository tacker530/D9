require 'nmatrix'
require 'parallel'
require 'csv'

class Portal
  attr_accessor :latitude, :longitude, :name

  def initialize(latitude, longitude, name)
    @latitude = latitude
    @longitude = longitude
    @name = name
  end
end

class KDTree
  def initialize(points)
    @points = points
    @root = build_tree(points, 0)
  end

  def range_search(point, radius)
    results = []
    search(@root, point, radius, results)
    results
  end

  private

  def build_tree(points, depth)
    return nil if points.empty?

    axis = depth % 2
    points.sort { |a, b| a[axis] <=> b[axis] }
    median = points.length / 2

    node = Node.new(points[median], axis)
    node.left = build_tree(points[0...median], depth + 1)
    node.right = build_tree(points[median + 1...points.length], depth + 1)
    node
  end

  def search(node, point, radius, results)
    return if node.nil?

    distance = distance_between(node.point, point)
    if distance <= radius
      results << node.point
      search(node.left, point, radius, results)
      search(node.right, point, radius, results)
    elsif node.axis == 0
      if point[0] < node.point[0]
        search(node.left, point, radius, results)
      else
        search(node.right, point, radius, results)
      end
    else
      if point[1] < node.point[1]
        search(node.left, point, radius, results)
      else
        search(node.right, point, radius, results)
      end
    end
  end

  def distance_between(point1, point2)
    Math.sqrt((point1[0] - point2[0]) ** 2 + (point1[1] - point2[1]) ** 2)
  end
end

class Node
  attr_accessor :point, :axis, :left, :right

  def initialize(point, axis)
    @point = point
    @axis = axis
    @left = nil
    @right = nil
  end
end

class ControlFieldBuilder
  def initialize(multiplicity = 4)
    @multiplicity = multiplicity
  end

  def build_control_field(portals)
    coordinates = portals.map { |portal| [portal.latitude, portal.longitude] }.to_nm
    kdtree = KDTree.new(coordinates)

    control_fields = []
    portals.each_combination(3) do |combination|
      recursive_build_control_field(portals, kdtree, combination, compute_triangle_area(combination), @multiplicity)
    end

    control_fields = Parallel.map(control_fields, in_threads: 4) do |control_field|
      compute_control_field(control_field)
    end

    control_fields
  end

  private

  def recursive_build_control_field(portals, kdtree, current_combination, current_area, current_multiplicity)
    return if current_area < 0.1

    nearby_portals = kdtree.range_search(current_combination, 0.1)
    nearby_portals.each do |portal|
      new_area = compute_triangle_area(current_combination, portal)
      if new_area > 0
        control_fields << [current_combination, portal]
        recursive_build_control_field(portals, kdtree, [current_combination, portal], new_area, current_multiplicity - 1)
      end
    end
  end

  def compute_triangle_area(triangle)
    # Implementation of the triangle area computation
  end

  def compute_control_field(control_field)
    # Implementation of the control field computation
  end
end

# Example usage
builder = ControlFieldBuilder.new(4)
portals = []
CSV.foreach('portals.csv', headers: false) do |row|
  latitude, longitude, name = row
  portals << Portal.new(latitude.to_f, longitude.to_f, name)
end
control_fields = builder.build_control_field(portals)
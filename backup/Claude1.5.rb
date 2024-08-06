require 'csv'
require 'numo/narray'
require 'parallel'
require 'optparse'

# ポータルを表すクラス
class Portal
  attr_reader :lat, :lon, :name

  def initialize(lat, lon, name)
    @lat = lat.to_f
    @lon = lon.to_f
    @name = name
  end
end

# 空間を四分割して管理するQuadTreeクラス
class QuadTree
  attr_reader :boundary, :portals

  def initialize(boundary)
    @boundary = boundary
    @portals = []
    @divided = false
    @northwest = nil
    @northeast = nil
    @southwest = nil
    @southeast = nil
  end

  # ポータルを挿入するメソッド
  def insert(portal)
    return false unless @boundary.contains?(portal)

    if @portals.length < 4
      @portals << portal
      return true
    end

    subdivide unless @divided

    return true if @northwest.insert(portal)
    return true if @northeast.insert(portal)
    return true if @southwest.insert(portal)
    return true if @southeast.insert(portal)

    false
  end

  # 空間を4分割するメソッド
  def subdivide
    x = @boundary.x
    y = @boundary.y
    w = @boundary.width / 2
    h = @boundary.height / 2

    @northwest = QuadTree.new(Rect.new(x - w, y - h, w, h))
    @northeast = QuadTree.new(Rect.new(x + w, y - h, w, h))
    @southwest = QuadTree.new(Rect.new(x - w, y + h, w, h))
    @southeast = QuadTree.new(Rect.new(x + w, y + h, w, h))

    @divided = true
  end

  # 指定された範囲内のポータルを検索するメソッド
  def query(range)
    found = []
    return found unless @boundary.intersects?(range)

    @portals.each do |portal|
      found << portal if range.contains?(portal)
    end

    if @divided
      found.concat(@northwest.query(range))
      found.concat(@northeast.query(range))
      found.concat(@southwest.query(range))
      found.concat(@southeast.query(range))
    end

    found
  end
end

# 矩形領域を表すクラス
class Rect
  attr_reader :x, :y, :width, :height

  def initialize(x, y, width, height)
    @x = x
    @y = y
    @width = width
    @height = height
  end

  # ポータルが矩形内に含まれるかチェックするメソッド
  def contains?(portal)
    portal.lon >= @x - @width && portal.lon <= @x + @width &&
      portal.lat >= @y - @height && portal.lat <= @y + @height
  end

  # 他の矩形と交差するかチェックするメソッド
  def intersects?(other)
    !(other.x - other.width > @x + @width ||
      other.x + other.width < @x - @width ||
      other.y - other.height > @y + @height ||
      other.y + other.height < @y - @height)
  end
end

# CSVファイルからポータルデータを読み込むメソッド
def load_portals(file_path)
  portals = []
  CSV.foreach(file_path) do |row|
    portals << Portal.new(row[0], row[1], row[2])
  end
  portals
end

# QuadTreeを構築するメソッド
def build_quad_tree(portals)
  min_lat = portals.map(&:lat).min
  max_lat = portals.map(&:lat).max
  min_lon = portals.map(&:lon).min
  max_lon = portals.map(&:lon).max

  center_lat = (min_lat + max_lat) / 2
  center_lon = (min_lon + max_lon) / 2
  half_width = (max_lon - min_lon) / 2
  half_height = (max_lat - min_lat) / 2

  quad_tree = QuadTree.new(Rect.new(center_lon, center_lat, half_width, half_height))
  portals.each { |portal| quad_tree.insert(portal) }
  quad_tree
end

# 点が三角形内にあるかチェックするメソッド（行列計算を使用）
def points_in_triangle(points, triangle)
  p = Numo::DFloat.cast(points.map { |pt| [pt.lon, pt.lat] })
  t = Numo::DFloat.cast(triangle.map { |pt| [pt.lon, pt.lat] })

  v0 = t[1, true] - t[0, true]
  v1 = t[2, true] - t[0, true]
  v2 = p - t[0, true]

  d00 = (v0 * v0).sum
  d01 = (v0 * v1).sum
  d11 = (v1 * v1).sum
  d20 = (v2 * v0).sum(axis: 1)
  d21 = (v2 * v1).sum(axis: 1)

  denom = d00 * d11 - d01 * d01
  u = (d11 * d20 - d01 * d21) / denom
  v = (d00 * d21 - d01 * d20) / denom

  (u >= 0) & (v >= 0) & (u + v <= 1)
end

# 多重CFを検索するメソッド
def find_multi_cf(quad_tree, depth = 1, max_depth)
  result = []
  portals = quad_tree.query(quad_tree.boundary)

  Parallel.map(portals.combination(3).to_a, in_processes: 4) do |triangle|
    bounding_box = Rect.new(
      (triangle.map(&:lon).min + triangle.map(&:lon).max) / 2,
      (triangle.map(&:lat).min + triangle.map(&:lat).max) / 2,
      (triangle.map(&:lon).max - triangle.map(&:lon).min) / 2,
      (triangle.map(&:lat).max - triangle.map(&:lat).min) / 2
    )

    potential_inner_portals = quad_tree.query(bounding_box) - triangle
    inner_portals = potential_inner_portals.select { |p| points_in_triangle([p], triangle)[0] }

    if inner_portals.empty?
      { portals: triangle, depth: depth }
    elsif depth < max_depth
      inner_quad_tree = build_quad_tree(triangle + inner_portals)
      find_multi_cf(inner_quad_tree, depth + 1, max_depth)
    end
  end.compact.flatten
end

# コマンドラインオプションの解析
options = { max_depth: 4 }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby script_name.rb [options]"

  opts.on("-d", "--depth DEPTH", Integer, "多重度を指定（デフォルト: 4）") do |d|
    options[:max_depth] = d
  end

  opts.on("-h", "--help", "ヘルプを表示") do
    puts opts
    exit
  end
end.parse!

# メイン処理
portals = load_portals('portals.csv')
quad_tree = build_quad_tree(portals)
multi_cfs = find_multi_cf(quad_tree, 1, options[:max_depth])

puts "使用している最大深さ（多重度）: #{options[:max_depth]}"
puts "#{multi_cfs.length}個の多重CFが見つかりました:"
multi_cfs.each do |cf|
  puts "深さ: #{cf[:depth]}, ポータル: #{cf[:portals].map(&:name).join(', ')}"
end
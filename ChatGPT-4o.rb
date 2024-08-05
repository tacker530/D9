require 'csv'
require 'nmatrix'
require 'parallel'
require 'kdtree'
require 'optparse'

# コマンドライン引数の解析
options = { degree: 4 }  # デフォルトの多重度を4に設定

OptionParser.new do |opts|
  opts.banner = "Usage: ruby script.rb [options]"

  opts.on("-d", "--degree DEGREE", "Set the degree of CF (default: 4)") do |degree|
    options[:degree] = degree.to_i
  end
end.parse!

# ポータルクラスの定義
class Portal
  attr_accessor :latitude, :longitude, :name

  def initialize(latitude, longitude, name)
    @latitude = latitude.to_f
    @longitude = longitude.to_f
    @name = name
  end
end

# CSVファイルからポータルデータを読み込む関数
def read_portals_from_csv(file_path)
  portals = []
  CSV.foreach(file_path, headers: true) do |row|
    portals << Portal.new(row['latitude'], row['longitude'], row['name'])
  end
  portals
end

# 三角形内外判定関数
def is_point_in_triangle?(p, p0, p1, p2)
  matrix = NMatrix.new([3, 3], [p0.longitude - p.longitude, p0.latitude - p.latitude, 1,
                                p1.longitude - p.latitude, p1.latitude - p.latitude, 1,
                                p2.longitude - p.latitude, p2.latitude - p.latitude, 1])
  determinant = matrix.det
  determinant.abs <= 1e-10 # 小さな値を考慮した誤差
end

# リンクの交差判定関数
def do_lines_intersect?(p1, p2, p3, p4)
  def det(matrix)
    matrix.det
  end

  matrix1 = NMatrix.new([2, 2], [p2.longitude - p1.longitude, p3.longitude - p4.longitude,
                                 p2.latitude - p1.latitude, p3.latitude - p4.latitude])
  matrix2 = NMatrix.new([2, 2], [p3.longitude - p1.longitude, p3.longitude - p4.longitude,
                                 p3.latitude - p1.latitude, p3.latitude - p4.latitude])
  matrix3 = NMatrix.new([2, 2], [p2.longitude - p1.longitude, p3.longitude - p1.longitude,
                                 p2.latitude - p1.latitude, p3.latitude - p1.latitude])

  return false if matrix1.det == 0 && matrix2.det == 0

  (det(matrix1) * det(matrix2) < 0) && (det(matrix2) * det(matrix3) < 0)
end

# KdTreeを構築する関数
def build_kdtree(portals)
  points = portals.map { |portal| [portal.longitude, portal.latitude, portal] }
  Kdtree.new(points)
end

# 三角形内にあるポータルを探索する関数
def find_points_in_triangle(kdtree, p1, p2, p3)
  bounds = {
    min_lon: [p1.longitude, p2.longitude, p3.longitude].min,
    max_lon: [p1.longitude, p2.longitude, p3.longitude].max,
    min_lat: [p1.latitude, p2.latitude, p3.latitude].min,
    max_lat: [p1.latitude, p2.latitude, p3.latitude].max
  }

  candidates = kdtree.nearest_range(bounds[:min_lon], bounds[:min_lat], bounds[:max_lon], bounds[:max_lat])
  candidates = candidates.map { |_, _, portal| portal }
  candidates.select { |p| is_point_in_triangle?(p, p1, p2, p3) }
end

# 多重CFを構築する再帰関数
def construct_links_and_cfs(portals, existing_links, current_cf, all_cfs, kdtree, current_degree, max_degree)
  return if current_degree > max_degree

  portals.combination(3).each do |p1, p2, p3|
    if !existing_links.any? { |l| do_lines_intersect?(l[0], l[1], p3, p1) || do_lines_intersect?(l[0], l[1], p3, p2) }
      triangle = [p1, p2, p3]
      inner_portals = find_points_in_triangle(kdtree, p1, p2, p3)
      new_links = [[p1, p2], [p2, p3], [p3, p1]]

      all_cfs << { cf: triangle, links: existing_links + new_links }
      
      unless inner_portals.empty?
        construct_links_and_cfs(inner_portals, existing_links + new_links, triangle, all_cfs, kdtree, current_degree + 1, max_degree)
      end
    end
  end
end

# 全多重CFを構築する関数
def find_all_multiple_cfs(portals, max_degree)
  all_cfs = []
  kdtree = build_kdtree(portals)

  Parallel.each_with_index(portals.combination(3).to_a, in_threads: Parallel.processor_count) do |combination, index|
    p1, p2, p3 = combination
    all_combinations = [p1, p2, p3]
    inner_portals = portals.reject { |p| all_combinations.include?(p) }

    construct_links_and_cfs(inner_portals, [], nil, all_cfs, kdtree, 1, max_degree)
  end

  all_cfs
end

# CSVファイルの読み込み（例として 'portals.csv' ファイルを使用）
portals = read_portals_from_csv('portals.csv')

# 多重度を基にCFを構築
all_cfs = find_all_multiple_cfs(portals, options[:degree])

# 結果を出力
puts all_cfs
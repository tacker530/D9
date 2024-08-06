import numpy as np
import pandas as pd
import argparse

# ポータルクラス
class Portal:
    def __init__(self, latitude, longitude, name):
        self.latitude = latitude  # 緯度
        self.longitude = longitude  # 経度
        self.name = name  # ポータル名

# リンククラス (今回は使用していません)
class Link:
    def __init__(self, portal1, portal2):
        self.portal1 = portal1
        self.portal2 = portal2

# 全多重CF探索クラス
class MultiCFSeeker:
    def __init__(self, csv_file):
        self.portals = self.load_portals(csv_file) # CSVファイルからポータルデータを読み込む

    def load_portals(self, csv_file):
        """CSVファイルからポータルデータを読み込む"""
        df = pd.read_csv(csv_file)
        return [Portal(row.latitude, row.longitude, row.name) for _, row in df.iterrows()]

    def lines_intersect(self, p1, p2, p3, p4):
        """2つの線分(p1, p2)と(p3, p4)が交差するかどうかを判定"""
        # ベクトル計算で交差判定を行う
        v1 = np.array([p2.latitude - p1.latitude, p2.longitude - p1.longitude])
        v2 = np.array([p4.latitude - p3.latitude, p4.longitude - p3.longitude])
        v3 = np.array([p1.latitude - p3.latitude, p1.longitude - p3.longitude])

        cross1 = np.cross(v1, v3)
        cross2 = np.cross(v1, v2)
        cross3 = np.cross(v2, v3)

        return (cross1 * cross2 <= 0) & (cross2 * cross3 <= 0) & (cross1 != 0 or cross2 != 0)

    def point_in_triangle(self, p, a, b, c):
        """点pが三角形abcの中に含まれるかどうかを判定"""
        # ベクトル計算で判定
        ab = np.array([b.latitude - a.latitude, b.longitude - a.longitude])
        bc = np.array([c.latitude - b.latitude, c.longitude - b.longitude])
        ca = np.array([a.latitude - c.latitude, a.longitude - c.longitude])

        ap = np.array([p.latitude - a.latitude, p.longitude - a.longitude])
        bp = np.array([p.latitude - b.latitude, p.longitude - b.longitude])
        cp = np.array([p.latitude - c.latitude, p.longitude - c.longitude])

        cross1 = np.cross(ab, ap)
        cross2 = np.cross(bc, bp)
        cross3 = np.cross(ca, cp)

        return (cross1 >= 0) & (cross2 >= 0) & (cross3 >= 0) | \
               (cross1 <= 0) & (cross2 <= 0) & (cross3 <= 0)

    def find_multi_cfs(self, max_depth=4):
        """多重度(max_depth)まで探索する"""
        multi_cfs = []
        n = len(self.portals)
        for i in range(n - 2):
            for j in range(i + 1, n - 1):
                for k in range(j + 1, n):
                    a, b, c = self.portals[i], self.portals[j], self.portals[k]
                    
                    # 多重度チェックを追加
                    inner_portals = self.find_inner_portals_recursive(a, b, c, 1, max_depth)
                    
                    if inner_portals:
                        multi_cfs.append({
                            "portals": [a, b, c],
                            "inner_portals": inner_portals
                        })
        return multi_cfs

    def find_inner_portals_recursive(self, a, b, c, current_depth, max_depth):
        """再帰的に内部ポータルを探す"""
        inner_portals = [p for p in self.portals if p not in [a, b, c] and self.point_in_triangle(p, a, b, c)]
        
        # 最大多重度に達したら、それ以上探索しない
        if current_depth >= max_depth:
            return inner_portals

        # 各内部ポータルに対して再帰的に探索
        for p in inner_portals:
            inner_portals.extend(self.find_inner_portals_recursive(a, b, p, current_depth + 1, max_depth))
            inner_portals.extend(self.find_inner_portals_recursive(b, c, p, current_depth + 1, max_depth))
            inner_portals.extend(self.find_inner_portals_recursive(c, a, p, current_depth + 1, max_depth))

        return inner_portals

if __name__ == "__main__":
    # コマンドライン引数を解析
    parser = argparse.ArgumentParser(description='全多重CF探索プログラム')
    parser.add_argument('csv_file', type=str, help='CSVファイルのパス')
    parser.add_argument('-d', '--depth', type=int, default=4, help='多重度 (初期値: 4)')
    args = parser.parse_args()

    # 全多重CF探索クラスのインスタンスを作成
    multi_cf_seeker = MultiCFSeeker(args.csv_file)

    # 全多重CFを探索 (指定された多重度を使用)
    multi_cfs = multi_cf_seeker.find_multi_cfs(max_depth=args.depth)

    # 結果を表示
    print("見つかった全多重CF:")
    for multi_cf in multi_cfs:
        print("  - 外側のポータル: {}, {}, {}".format(multi_cf["portals"][0].name, multi_cf["portals"][1].name, multi_cf["portals"][2].name))
        print("    - 内側のポータル: {}".format(", ".join([p.name for p in multi_cf["inner_portals"]])))

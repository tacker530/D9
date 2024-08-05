import numpy as np
import pandas as pd

class Portal:
    def __init__(self, latitude, longitude, name):
        self.latitude = latitude
        self.longitude = longitude
        self.name = name

class Link:
    def __init__(self, portal1, portal2):
        self.portal1 = portal1
        self.portal2 = portal2

class MultiCFSeeker:
    def __init__(self, csv_file):
        self.portals = self.load_portals(csv_file)

    def load_portals(self, csv_file):
        df = pd.read_csv(csv_file)
        return [Portal(row.latitude, row.longitude, row.name) for _, row in df.iterrows()]

    def lines_intersect(self, p1, p2, p3, p4):
        """線分(p1, p2)と線分(p3, p4)が交差するかどうかを判定"""
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
        # ベクトルで計算
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

    def find_multi_cfs(self):
        multi_cfs = []
        n = len(self.portals)
        for i in range(n - 2):
            for j in range(i + 1, n - 1):
                for k in range(j + 1, n):
                    a, b, c = self.portals[i], self.portals[j], self.portals[k]
                    inner_portals = [p for p in self.portals if p not in [a, b, c] and self.point_in_triangle(p, a, b, c)]

                    if inner_portals:
                        multi_cfs.append({
                            "portals": [a, b, c],
                            "inner_portals": inner_portals
                        })
        return multi_cfs

# CSVファイルのパス
csv_file = 'portals.csv'

# 全多重CF探索クラスのインスタンスを作成
multi_cf_seeker = MultiCFSeeker(csv_file)

# 全多重CFを探索
multi_cfs = multi_cf_seeker.find_multi_cfs()

# 結果を表示
print("見つかった全多重CF:")
for multi_cf in multi_cfs:
    print("  - 外側のポータル: {}, {}, {}".format(multi_cf["portals"][0].name, multi_cf["portals"][1].name, multi_cf["portals"][2].name))
    print("    - 内側のポータル: {}".format(", ".join([p.name for p in multi_cf["inner_portals"]])))

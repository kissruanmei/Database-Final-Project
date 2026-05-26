"""
辅助脚本：执行 SQL 文件，自动按 GO 分割批次
用法: python run_sql.py <sql_file>
"""
import sys
import pyodbc

def run_sql_file(filepath):
    conn_str = (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        "SERVER=localhost;"
        "DATABASE=CampusVehicleDB;"
        "Trusted_Connection=yes;"
        "TrustServerCertificate=yes;"
    )
    conn = pyodbc.connect(conn_str)
    conn.autocommit = True
    cursor = conn.cursor()

    with open(filepath, 'r', encoding='utf-8-sig') as f:
        content = f.read()

    # 按 GO 分割批次
    batches = []
    current = []
    for line in content.split('\n'):
        stripped = line.strip()
        if stripped.upper() == 'GO':
            if current:
                batches.append('\n'.join(current))
                current = []
        else:
            current.append(line)
    if current:
        batches.append('\n'.join(current))

    for i, batch in enumerate(batches):
        batch = batch.strip()
        if not batch or batch.startswith('--'):
            continue
        try:
            cursor.execute(batch)
            print(f"  [批次 {i+1}] 执行成功")
        except Exception as e:
            print(f"  [批次 {i+1}] 执行失败: {e}")

    cursor.close()
    conn.close()
    print("\n全部执行完毕")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python run_sql.py <sql_file>")
        sys.exit(1)
    run_sql_file(sys.argv[1])

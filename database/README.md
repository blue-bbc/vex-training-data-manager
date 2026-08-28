# Supabase 数据库迁移

请在新的 Supabase 项目中按编号顺序执行 SQL 文件。执行前先备份，生产环境应先在测试项目验证。

执行 `002_promote_first_admin.sql` 前，先通过应用注册管理员账号，再将脚本中的 `REPLACE_WITH_ADMIN_EMAIL` 替换为该账号邮箱。

这些脚本包含行级安全策略。前端页面中的角色判断只负责界面展示，真正的数据权限以 Supabase RLS 为准。

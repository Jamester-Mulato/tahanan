import { query } from "../config/db";

export async function getTenantStatuses(
  tenantId: string,
  boardingHouseId: string,
  academicYearId?: string
) {
  const result = await query(
    `
    SELECT
      tms.id,
      tms.tenant_id AS "tenantId",
      tms.academic_year_id AS "academicYearId",
      ay.name AS "academicYear",
      tms.month_start AS "monthStart",
      tms.status
    FROM tenant_monthly_statuses tms
    JOIN academic_years ay ON ay.id = tms.academic_year_id
    WHERE tms.tenant_id = $1
      AND tms.boarding_house_id = $2
      AND ($3::uuid IS NULL OR tms.academic_year_id = $3::uuid)
    ORDER BY tms.month_start
    `,
    [tenantId, boardingHouseId, academicYearId ?? null]
  );

  return result.rows;
}

export async function upsertTenantStatus(
  boardingHouseId: string,
  tenantId: string,
  academicYearId: string | undefined,
  monthStart: string | undefined,
  status: "paid" | "partial" | "unpaid",
  updatedBy: string
) {
  let resolvedYearId = academicYearId;
  if (!resolvedYearId) {
    const yearRes = await query(
      `SELECT id FROM academic_years WHERE boarding_house_id = $1 AND is_active = TRUE LIMIT 1`,
      [boardingHouseId]
    );
    if ((yearRes.rowCount ?? 0) > 0) {
      resolvedYearId = yearRes.rows[0].id;
    } else {
      const newYearRes = await query(
        `INSERT INTO academic_years (boarding_house_id, name, starts_on, ends_on, is_active)
         VALUES ($1, 'Current Year', date_trunc('year', now())::date, (date_trunc('year', now()) + interval '1 year')::date, TRUE)
         RETURNING id`,
        [boardingHouseId]
      );
      resolvedYearId = newYearRes.rows[0].id;
    }
  }

  const resolvedMonth =
    monthStart ??
    new Date().toISOString().substring(0, 7) + "-01";

  const result = await query(
    `
    INSERT INTO tenant_monthly_statuses (
      boarding_house_id,
      tenant_id,
      academic_year_id,
      month_start,
      status,
      updated_by
    )
    VALUES ($1, $2, $3, $4, $5, $6)
    ON CONFLICT (tenant_id, academic_year_id, month_start)
    DO UPDATE SET
      status = EXCLUDED.status,
      updated_by = EXCLUDED.updated_by,
      updated_at = NOW()
    RETURNING
      id,
      tenant_id AS "tenantId",
      academic_year_id AS "academicYearId",
      month_start AS "monthStart",
      status
    `,
    [boardingHouseId, tenantId, resolvedYearId, resolvedMonth, status, updatedBy]
  );

  return result.rows[0];
}


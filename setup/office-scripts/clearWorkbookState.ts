type ClearRequest = {
  worksheetName?: string;
  resetRanges?: string[];
};

function main(workbook: ExcelScript.Workbook, request: ClearRequest = {}) {
  const worksheetName = request.worksheetName ?? "Calculator";
  const sheet = workbook.getWorksheet(worksheetName);
  if (!sheet) {
    throw new Error(`Worksheet '${worksheetName}' が見つかりません。`);
  }

  const resetRanges = request.resetRanges ?? [
    "B2:B6",
    "E2:E4"
  ];

  resetRanges.forEach((address) => {
    sheet.getRange(address).clear(ExcelScript.ClearApplyTo.contents);
  });

  return {
    worksheetName,
    clearedRanges: resetRanges
  };
}

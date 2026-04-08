type OutputRequest = {
  worksheetName?: string;
  outputCells?: {
    bracketCount?: string;
    ruleVersion?: string;
    calculatedAt?: string;
  };
};

function main(workbook: ExcelScript.Workbook, request: OutputRequest = {}) {
  const worksheetName = request.worksheetName ?? "Calculator";
  const sheet = workbook.getWorksheet(worksheetName);
  if (!sheet) {
    throw new Error(`Worksheet '${worksheetName}' が見つかりません。`);
  }

  const outputCells = {
    bracketCount: "E2",
    ruleVersion: "E3",
    calculatedAt: "E4",
    ...request.outputCells
  };

  return {
    bracketCount: sheet.getRange(outputCells.bracketCount).getValue(),
    ruleVersion: sheet.getRange(outputCells.ruleVersion).getText(),
    calculatedAt: sheet.getRange(outputCells.calculatedAt).getText()
  };
}

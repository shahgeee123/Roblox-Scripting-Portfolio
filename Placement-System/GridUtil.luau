--!strict
local Grid = {}
Grid.CELL = 4

function Grid.isInteger(value: any): boolean
	return typeof(value) == "number" and value == value
		and math.abs(value) <= 10000 and value % 1 == 0
end

function Grid.worldToCell(plot: BasePart, position: Vector3): (number, number)
	local point = plot.CFrame:PointToObjectSpace(position)
	return math.round(point.X / Grid.CELL), math.round(point.Z / Grid.CELL)
end

function Grid.fits(plot: BasePart, x: number, z: number): boolean
	return math.abs(x * Grid.CELL) + Grid.CELL / 2 <= plot.Size.X / 2
		and math.abs(z * Grid.CELL) + Grid.CELL / 2 <= plot.Size.Z / 2
end

function Grid.toCFrame(plot: BasePart, x: number, z: number, turn: number): CFrame
	return plot.CFrame * CFrame.new(x * Grid.CELL, plot.Size.Y / 2 + 2, z * Grid.CELL)
		* CFrame.Angles(0, turn * math.pi / 2, 0)
end

return table.freeze(Grid)

--[[
	PlayerScriptsLoader - This script requires and instantiates the PlayerModule singleton
	
	2018 PlayerScripts Update - AllYourBlox	
	2020 Modifications - EgoMoose
--]]

local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)
local ZERO = Vector3.new(0, 0, 0)
local IDENTITYCF = CFrame.new()
local TERRAIN = game.Workspace.Terrain

local localPlayer = game:GetService("Players").LocalPlayer
local playerModule = script.Parent:WaitForChild("PlayerModule")
local cameraModule = playerModule:WaitForChild("CameraModule")
local baseCameraModule = cameraModule:WaitForChild("BaseCamera")
local popperCamModule = cameraModule:WaitForChild("Poppercam")
local utilsModule = cameraModule:WaitForChild("CameraUtils")

-- Functions

local function getRotationBetween(u, v, axis)
	local dot, uxv = u:Dot(v), u:Cross(v)
	if (dot < -0.99999) then return CFrame.fromAxisAngle(axis, math.pi) end
	return CFrame.new(0, 0, 0, uxv.x, uxv.y, uxv.z, 1 + dot)
end

-- PopperCam mod

local Poppercam = require(popperCamModule)
local ZoomController = require(cameraModule:WaitForChild("ZoomController"))

function Poppercam:Update(renderDt, desiredCameraCFrame, desiredCameraFocus, cameraController)
	local rotatedFocus = desiredCameraFocus * (desiredCameraCFrame - desiredCameraCFrame.p)
	local extrapolation = self.focusExtrapolator:Step(renderDt, rotatedFocus)
	local zoom = ZoomController.Update(renderDt, rotatedFocus, extrapolation)
	return rotatedFocus*CFrame.new(0, 0, zoom), desiredCameraFocus
end

-- BaseCamera mod

local BaseCamera = require(baseCameraModule)

BaseCamera.UpCFrame = IDENTITYCF

function BaseCamera:UpdateUpCFrame(cf)
	self.UpCFrame = cf
end

function BaseCamera:CalculateNewLookCFrame(suppliedLookVector)
	local currLookVector = suppliedLookVector or self:GetCameraLookVector()
	currLookVector = self.UpCFrame:VectorToObjectSpace(currLookVector)
	
	local currPitchAngle = math.asin(currLookVector.y)
	local yTheta = math.clamp(self.rotateInput.y, -MAX_Y + currPitchAngle, -MIN_Y + currPitchAngle)
	local constrainedRotateInput = Vector2.new(self.rotateInput.x, yTheta)
	local startCFrame = CFrame.new(ZERO, currLookVector)
	local newLookCFrame = CFrame.Angles(0, -constrainedRotateInput.x, 0) * startCFrame * CFrame.Angles(-constrainedRotateInput.y,0,0)
	
	return newLookCFrame
end

-- Camera mod

local Camera = require(cameraModule)

local lastUpCFrame = IDENTITYCF

Camera.UpVector = Vector3.new(0, 1, 0)
Camera.TransitionRate = 0.15
Camera.UpCFrame = IDENTITYCF

function Camera:GetUpVector(oldUpVector)
	return oldUpVector
end

function Camera:CalculateUpCFrame()
	local oldUpVector = self.UpVector
	local newUpVector = self:GetUpVector(oldUpVector)
	
	local backup = game.Workspace.CurrentCamera.CFrame.RightVector
	local transitionCF = getRotationBetween(oldUpVector, newUpVector, backup)
	local vecSlerpCF = IDENTITYCF:Lerp(transitionCF, self.TransitionRate)
	
	self.UpVector = vecSlerpCF * oldUpVector
	self.UpCFrame = vecSlerpCF * self.UpCFrame
	
	lastUpCFrame = self.UpCFrame
end

function Camera:Update(dt)
	if self.activeCameraController then	
		local newCameraCFrame, newCameraFocus = self.activeCameraController:Update(dt)
		self.activeCameraController:ApplyVRTransform()
		
		self:CalculateUpCFrame()
		self.activeCameraController:UpdateUpCFrame(self.UpCFrame)
		
		local offset = newCameraFocus:Inverse() * newCameraCFrame
		newCameraCFrame = newCameraFocus * self.UpCFrame * offset
		
		if (self.activeCameraController.lastCameraTransform) then
			self.activeCameraController.lastCameraTransform = newCameraCFrame
			self.activeCameraController.lastCameraFocus = newCameraFocus
		end
		
		if self.activeOcclusionModule then
			newCameraCFrame, newCameraFocus = self.activeOcclusionModule:Update(dt, newCameraCFrame, newCameraFocus)
		end
		
		game.Workspace.CurrentCamera.CFrame = newCameraCFrame
		game.Workspace.CurrentCamera.Focus = newCameraFocus
		
		if self.activeTransparencyController then
			self.activeTransparencyController:Update()
		end
	end
end

--

local Utils = require(utilsModule)

function Utils.GetAngleBetweenXZVectors(v1, v2)
	local upCFrame = lastUpCFrame -- this is kind of lame, but it works
	v1 = upCFrame:VectorToObjectSpace(v1)
	v2 = upCFrame:VectorToObjectSpace(v2)
	return math.atan2(v2.X*v1.Z-v2.Z*v1.X, v2.X*v1.X+v2.Z*v1.Z)
end

--

require(playerModule)
script:WaitForChild("Loaded").Value = true

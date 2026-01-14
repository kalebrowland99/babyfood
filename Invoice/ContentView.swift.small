//
//  ContentView.swift
//  Invoice
//
//  Created by Eliana Silva on 8/19/24.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct ContentView: View {
    @State private var selectedDay = 5 // Tuesday is selected (index 5 in the week)
    @State private var selectedTab = 1 // Start with Progress tab
    @State private var streakCount = 0
    @State private var showAddMenu = false
    @State private var showScanFlow = false
    @State private var showFoodDatabase = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.97, green: 0.97, blue: 0.98),
                        Color(red: 0.96, green: 0.96, blue: 0.97)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Tab Content
                if selectedTab == 0 {
                    HomeView(selectedDay: $selectedDay, streakCount: $streakCount)
                } else if selectedTab == 1 {
                    ProgressView()
                } else if selectedTab == 2 {
                    ProfileView()
                }
                
                // Bottom Navigation
                VStack {
                    Spacer()
                    
                    ZStack {
                        // Tab Bar Background
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white.opacity(0.97))
                            .background(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: -4)
                            .frame(height: 82 + geometry.safeAreaInsets.bottom)
                        
                        HStack(spacing: 0) {
                            // Home Tab
                            TabButton(icon: "house.fill", label: "Home", isSelected: selectedTab == 0) {
                                selectedTab = 0
                            }
                            
                            // Progress Tab
                            TabButton(icon: "chart.bar.fill", label: "Progress", isSelected: selectedTab == 1) {
                                selectedTab = 1
                            }
                            
                            // Profile Tab
                            TabButton(icon: "person.fill", label: "Profile", isSelected: selectedTab == 2) {
                                selectedTab = 2
                            }
                            
                            // Add Button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAddMenu.toggle()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.15, green: 0.15, blue: 0.20))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: showAddMenu ? "xmark" : "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .offset(x: -8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 18))
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Add Menu Overlay
                if showAddMenu {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showAddMenu = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // Food Database Button
                                Button(action: {
                                    // Open food database
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showFoodDatabase = true
                                    }
                                }) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 48, weight: .regular))
                                            .foregroundColor(.black)
                                        
                                        Text("Food Database")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color.white)
                                    .cornerRadius(24)
                                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                                }
                                
                                // Scan Food Button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showScanFlow = true
                                    }
                                }) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 48, weight: .regular))
                                            .foregroundColor(.black)
                                        
                                        Text("Scan food")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color.white)
                                    .cornerRadius(24)
                                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 120)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Scan Flow Overlay
                if showScanFlow {
                    FoodScanFlow(isPresented: $showScanFlow)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .fullScreenCover(isPresented: $showFoodDatabase) {
            FoodDatabaseView(isPresented: $showFoodDatabase)
        }
    }
    
    func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Camera access granted")
                    // Open camera scanner here
                } else {
                    print("Camera access denied")
                    // Show alert or message to user
                }
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Binding var selectedDay: Int
    @Binding var streakCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Header
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.black)
                    Text("Cal AI")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // Streak counter
                HStack(spacing: 5) {
                    Text("🔥")
                        .font(.system(size: 15))
                    Text("\(streakCount)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.white)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            
            // Week View
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    VStack(spacing: 7) {
                        Text(dayName(for: index))
                            .font(.system(size: 12, weight: .regular))
                            .kerning(0.2)
                            .foregroundColor(index == selectedDay ? .black : Color.black.opacity(0.35))
                        
                        ZStack {
                            if index == selectedDay {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                                
                                Circle()
                                    .stroke(Color.black.opacity(0.25), lineWidth: 2)
                                    .frame(width: 30, height: 30)
                            } else {
                                DashedCircle(lineWidth: 1.5, dashLength: 3, color: Color.black.opacity(0.15))
                                    .frame(width: 30, height: 30)
                            }
                            
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: index == selectedDay ? .medium : .regular))
                                .foregroundColor(index == selectedDay ? .black : Color.black.opacity(0.3))
                        }
                    }
                    .padding(.vertical, index == selectedDay ? 10 : 0)
                    .padding(.horizontal, index == selectedDay ? 6 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(index == selectedDay ? Color.white : Color.clear)
                            .shadow(color: index == selectedDay ? Color.black.opacity(0.06) : Color.clear, radius: 8, x: 0, y: 2)
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Main Calorie Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 6)
                        
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("1388")
                                    .font(.system(size: 45, weight: .bold))
                                    .kerning(-2.5)
                                    .foregroundColor(.black)
                                
                                HStack(spacing: 8) {
                                    Text("Calories left")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(Color.black.opacity(0.5))
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.black.opacity(0.5))
                                        Text("+1")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.black.opacity(0.5))
                                    }
                                }
                            }
                            .padding(.leading, 34)
                            
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 10)
                                    .frame(width: 128, height: 128)
                                
                                Text("🔥")
                                    .font(.system(size: 42))
                            }
                            .padding(.trailing, 30)
                        }
                        .padding(.vertical, 28)
                    }
                    .frame(height: 190)
                    .padding(.horizontal, 20)
                    
                    // Macro Cards
                    HStack(spacing: 12) {
                        MacroCard(
                            amount: "136g",
                            label: "Protein left",
                            icon: "🍗",
                            circleColor: Color(red: 0.89, green: 0.85, blue: 0.88).opacity(0.5)
                        )
                        .frame(maxWidth: .infinity)
                        
                        MacroCard(
                            amount: "123g",
                            label: "Carbs left",
                            icon: "🌾",
                            circleColor: Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.5)
                        )
                        .frame(maxWidth: .infinity)
                        
                        MacroCard(
                            amount: "38g",
                            label: "Fat left",
                            icon: "💧",
                            circleColor: Color(red: 0.87, green: 0.90, blue: 0.95).opacity(0.5)
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)
                    
                    // Page indicator dots
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    
                    // Recently Uploaded Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recently uploaded")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                        
                        // Meal Card
                        ZStack {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 2)
                            
                            VStack(spacing: 0) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.95, green: 0.95, blue: 0.96))
                                            .frame(width: 65, height: 65)
                                        
                                        Text("🥗")
                                            .font(.system(size: 34))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 5) {
                                        Rectangle()
                                            .fill(Color(red: 0.92, green: 0.92, blue: 0.93))
                                            .frame(width: 120, height: 10)
                                            .cornerRadius(5)
                                        
                                        Rectangle()
                                            .fill(Color(red: 0.94, green: 0.94, blue: 0.95))
                                            .frame(width: 85, height: 8)
                                            .cornerRadius(4)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.5))
                                .cornerRadius(24)
                                
                                Text("Tap + to add your first meal of the day")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 30)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .frame(height: 195)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 10)
                    
                    Spacer(minLength: 100)
                }
            }
        }
    }
    
    func dayName(for index: Int) -> String {
        let days = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]
        return days[index]
    }
}

// MARK: - Progress View
struct ProgressView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Progress Header
                Text("Progress")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 8)
                
                // Day Streak Card
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        
                        VStack(spacing: 12) {
                            ZStack {
                                // Fire emoji with sparkles
                                Text("🔥")
                                    .font(.system(size: 72))
                                
                                // Sparkles positioned around the fire
                                Text("✨")
                                    .font(.system(size: 20))
                                    .offset(x: -35, y: -25)
                                
                                Text("✨")
                                    .font(.system(size: 16))
                                    .offset(x: 30, y: -20)
                                
                                Text("✨")
                                    .font(.system(size: 12))
                                    .offset(x: -20, y: -35)
                                
                                // White circle with 0
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text("0")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(Color(red: 0.95, green: 0.62, blue: 0.35))
                                    )
                                    .offset(y: 25)
                            }
                            .frame(height: 100)
                            
                            Text("Day Streak")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color.black.opacity(0.6))
                        }
                        .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                
                // Current Weight Card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current Weight")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.5))
                                
                                Text("148 lbs")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.black)
                                    .fixedSize()
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Next weigh-in: 7d")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.5))
                                    .fixedSize()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.black.opacity(0.08))
                                    )
                            }
                        }
                        
                        // Progress bar placeholder
                        Rectangle()
                            .fill(Color(red: 0.95, green: 0.95, blue: 0.96))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        HStack {
                            Text("Start: 148 lbs")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.5))
                            
                            Spacer()
                            
                            Text("Goal: 135.6 lbs")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.5))
                        }
                        
                        Text("At your goal by Jul 16, 2026.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                    .padding(24)
                }
                .padding(.horizontal, 20)
                
                // Weight Progress Chart
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Weight Progress")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.black.opacity(0.4))
                                
                                Text("0% of goal")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.5))
                            }
                        }
                        
                        // Chart
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Y-axis labels and grid lines
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach([152, 150, 148, 146, 144], id: \.self) { value in
                                        HStack(spacing: 8) {
                                            Text("\(value)")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(Color.black.opacity(0.4))
                                                .frame(width: 30, alignment: .trailing)
                                            
                                            Rectangle()
                                                .fill(Color.black.opacity(0.06))
                                                .frame(height: 1)
                                        }
                                        
                                        if value != 144 {
                                            Spacer()
                                        }
                                    }
                                }
                                
                                // Weight line (at 148)
                                HStack(spacing: 8) {
                                    Text("")
                                        .frame(width: 30)
                                    
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(height: 2)
                                }
                                .offset(y: geometry.size.height * 0.5) // Position at 148 (middle)
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding(24)
                }
                .padding(.horizontal, 20)
                
                // BMI Card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Your BMI")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.black.opacity(0.3))
                            }
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("25.4")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("Your weight is")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.5))
                            
                            Text("Overweight")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(red: 0.82, green: 0.65, blue: 0.42))
                        }
                        
                        // BMI Scale Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Colored sections
                                HStack(spacing: 0) {
                                    // Underweight - Blue (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.40, green: 0.60, blue: 0.85))
                                        .frame(width: geometry.size.width * 0.25)
                                    
                                    // Healthy - Green (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.45, green: 0.75, blue: 0.55))
                                        .frame(width: geometry.size.width * 0.25)
                                    
                                    // Overweight - Orange/Tan (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.85, green: 0.68, blue: 0.45))
                                        .frame(width: geometry.size.width * 0.25)
                                    
                                    // Obese - Red/Brown (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.80, green: 0.50, blue: 0.50))
                                        .frame(width: geometry.size.width * 0.25)
                                }
                                .frame(height: 14)
                                .cornerRadius(7)
                                
                                // Current BMI indicator line
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 3, height: 24)
                                    .offset(x: geometry.size.width * 0.53) // 25.4 BMI position
                            }
                        }
                        .frame(height: 24)
                        
                        // BMI Categories
                        HStack(spacing: 4) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(red: 0.40, green: 0.60, blue: 0.85))
                                        .frame(width: 8, height: 8)
                                    
                                    Text("Underweight")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .fixedSize()
                                }
                                
                                Text("<18.5")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .padding(.leading, 12)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(red: 0.45, green: 0.75, blue: 0.55))
                                        .frame(width: 8, height: 8)
                                    
                                    Text("Healthy")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .fixedSize()
                                }
                                
                                Text("18.5–24.9")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .padding(.leading, 12)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(red: 0.85, green: 0.68, blue: 0.45))
                                        .frame(width: 8, height: 8)
                                    
                                    Text("Overweight")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .fixedSize()
                                }
                                
                                Text("25.0–29.9")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .padding(.leading, 12)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(red: 0.80, green: 0.50, blue: 0.50))
                                        .frame(width: 8, height: 8)
                                    
                                    Text("Obese")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .fixedSize()
                                }
                                
                                Text(">30.0")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .padding(.leading, 12)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    
    // Debug function to reset app state
    private func resetAppState() {
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Logout user
        do {
            try authManager.signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
        
        print("🔧 DEBUG: App state reset - returning to login screen")
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Profile Header
                Text("Profile")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 8)
                
                // User Info Card
                if let user = authManager.user {
                    VStack(spacing: 12) {
                        // User Avatar
                        Circle()
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.20))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(user.displayName?.prefix(1).uppercased() ?? user.email?.prefix(1).uppercased() ?? "U")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        // User Name
                        if let displayName = user.displayName {
                            Text(displayName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        
                        // User Email
                        if let email = user.email {
                            Text(email)
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 20)
                }
                
                // Personal Details
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "person.text.rectangle",
                        title: "Personal Details",
                        action: {}
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Preferences Header
                Text("Preferences")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Language
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "character.textbox",
                        title: "Language",
                        action: {}
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Support Header
                Text("Support")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Support Email
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "envelope",
                        title: "Support Email",
                        action: {}
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Legal Header
                Text("Legal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Legal Section
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "doc.text",
                        title: "Terms and Conditions",
                        action: {}
                    )
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    ProfileButton(
                        icon: "checkmark.shield",
                        title: "Privacy Policy",
                        action: {}
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Account Actions Header
                Text("Account Actions")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Account Actions
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Logout",
                        action: {
                            showLogoutAlert = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    ProfileButton(
                        icon: "person.crop.circle.badge.minus",
                        title: "Delete Account",
                        action: {
                            showDeleteAlert = true
                        }
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Debug Section
                #if DEBUG
                Text("Debug")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.orange.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "arrow.counterclockwise.circle.fill",
                        title: "🔧 Reset App & Logout (Debug)",
                        action: {
                            resetAppState()
                        }
                    )
                }
                .background(Color.orange.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                #endif
            }
            .padding(.bottom, 120)
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                do {
                    try authManager.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await authManager.user?.delete()
                        try authManager.signOut()
                    } catch {
                        print("Error deleting account: \(error.localizedDescription)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
}

// MARK: - Profile Button
struct ProfileButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.black)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

struct MacroCard: View {
    let amount: String
    let label: String
    let icon: String
    let circleColor: Color
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 2)
            
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(amount)
                        .font(.system(size: 26, weight: .bold)) // Smaller macro numbers
                        .foregroundColor(.black)
                    
                    Text(label)
                        .font(.system(size: 12, weight: .regular)) // #7: Smaller labels
                        .foregroundColor(Color.black.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4) // #9: Position higher
                
                Spacer(minLength: 0)
                
                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 68, height: 68) // #18: Smaller circles (was 78)
                    
                    Text(icon)
                        .font(.system(size: 24)) // #17: Smaller icons (was 28)
                        .offset(y: 2) // #11: Lower in circle
                }
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(height: 155) // #16: Shorter height (was 168)
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) { // Tighter spacing
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium)) // #20: Smaller icons
                    .foregroundColor(isSelected ? .black : Color.black.opacity(0.35))
                
                Text(label)
                    .font(.system(size: 10, weight: .medium)) // #9: Smaller labels
                    .foregroundColor(isSelected ? .black : Color.black.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// Custom dashed circle for unselected days with exactly 12 dashes
struct DashedCircle: View {
    let lineWidth: CGFloat
    let dashLength: CGFloat
    let color: Color
    
    var body: some View {
        // For a 30pt diameter circle (radius 15), circumference = 2πr ≈ 94.25
        // 12 dashes means 12 dashes + 12 gaps = 24 segments
        // Each segment = 94.25 / 24 ≈ 3.93
        let calculatedDashLength: CGFloat = 3.9
        
        Circle()
            .stroke(style: StrokeStyle(
                lineWidth: lineWidth,
                dash: [calculatedDashLength, calculatedDashLength]
            ))
            .foregroundColor(color)
    }
}

// MARK: - Food Scan Flow
struct FoodScanFlow: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0 // 0-3: onboarding, 4: camera, 5: food detail
    @State private var scannedFood: ScannedFood?
    
    var body: some View {
        ZStack {
            if currentStep < 4 {
                ScanOnboardingView(currentStep: $currentStep, isPresented: $isPresented)
            } else if currentStep == 4 {
                CameraScanView(currentStep: $currentStep, scannedFood: $scannedFood)
            } else if currentStep == 5 {
                FoodDetailView(food: scannedFood ?? ScannedFood.sample, isPresented: $isPresented)
            }
        }
    }
}

// MARK: - Scan Onboarding View
struct ScanOnboardingView: View {
    @Binding var currentStep: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with image and content
                VStack(spacing: 0) {
                    // Status bar area
                    HStack {
                        Spacer()
                    }
                    .frame(height: 44)
                    
                    Spacer()
                    
                    // Content based on current step
                    if currentStep == 0 {
                        OnboardingStep1()
                    } else if currentStep == 1 {
                        OnboardingStep2()
                    } else if currentStep == 2 {
                        OnboardingStep3()
                    }
                    
                    Spacer()
                }
                
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index == currentStep ? Color.black : Color.black.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 24)
                
                // Next/Scan now button
                Button(action: {
                    if currentStep < 2 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentStep += 1
                        }
                    } else {
                        currentStep = 4
                    }
                }) {
                    Text(currentStep == 2 ? "Scan now" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.20))
                        .cornerRadius(28)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingStep1: View {
    var body: some View {
        VStack(spacing: 32) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .frame(width: 310, height: 310)
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(Color.black.opacity(0.3))
            }
            
            VStack(spacing: 20) {
                Text("Get the best scan:")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Hold still")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Use lots of light")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Ensure all ingredients are visible")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

struct OnboardingStep2: View {
    var body: some View {
        VStack(spacing: 32) {
            // Image placeholder showing food scan
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .frame(width: 310, height: 310)
                
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60, weight: .regular))
                        .foregroundColor(Color.black.opacity(0.3))
                    
                    Text("AI analyzing...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.4))
                }
            }
            
            VStack(spacing: 20) {
                Text("AI analyzes your food")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Ingredients are identified")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Takes a few seconds")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("You'll see the calories and macros")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

struct OnboardingStep3: View {
    var body: some View {
        VStack(spacing: 32) {
            // Image placeholder showing food label
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .frame(width: 310, height: 310)
                
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 70, weight: .light))
                        .foregroundColor(Color.black.opacity(0.3))
                    
                    Text("ORGANIC")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.2))
                    
                    Text("BROCCOLETTE")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.black.opacity(0.2))
                }
            }
            
            VStack(spacing: 20) {
                Text("For highest accuracy:")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Or take a photo of the food label")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Alternatively, search the food database")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Camera Scan View
struct CameraScanView: View {
    @Binding var currentStep: Int
    @Binding var scannedFood: ScannedFood?
    @State private var flashOn = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        ZStack {
            // Camera preview placeholder
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top controls
                HStack {
                    Button(action: {
                        currentStep = 2
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        flashOn.toggle()
                    }) {
                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Camera controls
                HStack(spacing: 0) {
                    Spacer()
                    
                    // Shutter button
                    Button(action: {
                        // Simulate taking photo and moving to results
                        scannedFood = ScannedFood.sample
                        currentStep = 5
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    
                    Spacer()
                    
                    // Photo library button
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 40)
                }
                .padding(.bottom, 70)
            }
            
            // Speed indicator (top center)
            VStack {
                HStack(spacing: 4) {
                    Text(".5")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("x")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.top, 50)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage) { image in
                if image != nil {
                    // When image is selected, move to food detail
                    scannedFood = ScannedFood.sample
                    currentStep = 5
                }
            }
        }
    }
}

// MARK: - Food Detail View
struct FoodDetailView: View {
    let food: ScannedFood
    @Binding var isPresented: Bool
    @State private var showingFullDetails = false
    
    var body: some View {
        ZStack {
            // Background with food image
            if let imageName = food.imageName {
                Image(systemName: imageName)
                    .font(.system(size: 200))
                    .foregroundColor(Color.black.opacity(0.1))
                    .blur(radius: 50)
            }
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.20, green: 0.22, blue: 0.28),
                    Color(red: 0.25, green: 0.27, blue: 0.32)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Nutrition")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Food image/icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            Text(food.icon)
                                .font(.system(size: 60))
                        }
                        .padding(.top, 20)
                        
                        // Time badge
                        Text(food.timestamp)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(20)
                        
                        // Food name
                        HStack(spacing: 8) {
                            Text(food.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(food.servings)")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Button(action: {}) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        // Calories
                        HStack(spacing: 8) {
                            Text("🔥")
                                .font(.system(size: 20))
                            
                            Text("Calories")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Text("\(food.calories)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        
                        // Macros
                        HStack(spacing: 20) {
                            MacroItem(icon: "🍗", label: "Protein", value: "\(food.protein)g", color: Color(red: 0.89, green: 0.85, blue: 0.88))
                            MacroItem(icon: "🌾", label: "Carbs", value: "\(food.carbs)g", color: Color(red: 0.96, green: 0.93, blue: 0.87))
                            MacroItem(icon: "💧", label: "Fats", value: "\(food.fats)g", color: Color(red: 0.87, green: 0.90, blue: 0.95))
                        }
                        .padding(.horizontal, 24)
                        
                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                        
                        // Additional nutrients
                        if showingFullDetails {
                            VStack(spacing: 16) {
                                HStack(spacing: 20) {
                                    NutrientItem(icon: "🥦", label: "Fiber", value: "\(food.fiber)g", color: Color.purple.opacity(0.3))
                                    NutrientItem(icon: "🍬", label: "Sugar", value: "\(food.sugar)g", color: Color.pink.opacity(0.3))
                                    NutrientItem(icon: "🧂", label: "Sodium", value: "\(food.sodium)mg", color: Color.orange.opacity(0.3))
                                }
                                .padding(.horizontal, 24)
                                
                                // Health Score
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.pink)
                                        Text("Health Score")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Spacer()
                                        
                                        Text("\(food.healthScore)/10")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    // Health bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.white.opacity(0.2))
                                                .frame(height: 8)
                                            
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.yellow)
                                                .frame(width: geo.size.width * CGFloat(food.healthScore) / 10.0, height: 8)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                                .padding(.horizontal, 24)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Ingredients section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Ingredients")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {}) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Add")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            
                            ForEach(food.ingredients, id: \.self) { ingredient in
                                HStack {
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(ingredient)
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(.white.opacity(0.9))
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom button
                Button(action: {
                    isPresented = false
                }) {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.20))
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct MacroItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 48, height: 48)
                
                Text(icon)
                    .font(.system(size: 20))
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct NutrientItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 48, height: 48)
                
                Text(icon)
                    .font(.system(size: 20))
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    var onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImageSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Scanned Food Model
struct ScannedFood {
    let name: String
    let servings: Int
    let timestamp: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    let sugar: Int
    let sodium: Int
    let healthScore: Int
    let icon: String
    let imageName: String?
    let ingredients: [String]
    
    static let sample = ScannedFood(
        name: "Kopiko Black 3 in One",
        servings: 1,
        timestamp: "3:08 PM",
        calories: 90,
        protein: 1,
        carbs: 16,
        fats: 2,
        fiber: 0,
        sugar: 10,
        sodium: 40,
        healthScore: 5,
        icon: "☕️",
        imageName: nil,
        ingredients: [
            "Smoked Salmon - 180 cal, 85g",
            "Avocado - 120 cal, 78g"
        ]
    )
}

// MARK: - OpenFoodFacts Service
class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private let baseURL = "https://world.openfoodfacts.org"
    
    // Search for products by name
    func searchProducts(query: String) async throws -> [OFFProduct] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=25"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return response.products
    }
    
    // Get product by barcode
    func getProduct(barcode: String) async throws -> OFFProduct {
        let urlString = "\(baseURL)/api/v2/product/\(barcode).json"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        
        guard let product = response.product else {
            throw NSError(domain: "Product not found", code: 404)
        }
        
        return product
    }
}

// MARK: - OpenFoodFacts Models
struct OFFSearchResponse: Codable {
    let products: [OFFProduct]
}

struct OFFProductResponse: Codable {
    let product: OFFProduct?
}

struct OFFProduct: Codable, Identifiable {
    let code: String?
    let product_name: String?
    let brands: String?
    let image_url: String?
    let nutriments: OFFNutriments?
    let serving_size: String?
    
    var id: String { code ?? UUID().uuidString }
    
    var displayName: String {
        product_name ?? "Unknown Product"
    }
    
    var displayBrand: String {
        brands ?? ""
    }
}

struct OFFNutriments: Codable {
    let energy_kcal_100g: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let fiber_100g: Double?
    let sugars_100g: Double?
    let sodium_100g: Double?
    
    // Per serving
    let energy_kcal_serving: Double?
    let proteins_serving: Double?
    let carbohydrates_serving: Double?
    let fat_serving: Double?
    
    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_100g
        case carbohydrates_100g
        case fat_100g
        case fiber_100g
        case sugars_100g
        case sodium_100g
        case energy_kcal_serving = "energy-kcal_serving"
        case proteins_serving
        case carbohydrates_serving
        case fat_serving
    }
}

// MARK: - Food Database View
struct FoodDatabaseView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var searchResults: [OFFProduct] = []
    @State private var isLoading = false
    @State private var selectedProduct: OFFProduct?
    @State private var showProductDetail = false
    
    let tabTitles = ["All", "My foods", "My meals", "Saved foods"]
    
    // Common food suggestions
    let suggestions = [
        ("Peanut Butter", "94 cal", "tbsp"),
        ("Avocado", "130 cal", "serving"),
        ("Egg", "74 cal", "large"),
        ("Apples", "72 cal", "medium"),
        ("Spinach", "7 cal", "cup"),
        ("Banana", "105 cal", "medium"),
        ("Chicken Breast", "165 cal", "100g"),
        ("Rice", "130 cal", "cup")
    ]
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Log Food")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 16)
                
                // Tab Bar
                HStack(spacing: 0) {
                    ForEach(0..<tabTitles.count, id: \.self) { index in
                        Button(action: {
                            selectedTab = index
                        }) {
                            VStack(spacing: 8) {
                                Text(tabTitles[index])
                                    .font(.system(size: 16, weight: selectedTab == index ? .semibold : .regular))
                                    .foregroundColor(selectedTab == index ? .black : Color.black.opacity(0.4))
                                
                                Rectangle()
                                    .fill(selectedTab == index ? Color.black : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(Color.black.opacity(0.3))
                    
                    TextField("Describe what you ate", text: $searchText)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.black)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                        .onChange(of: searchText) { newValue in
                            if !newValue.isEmpty {
                                performSearch()
                            } else {
                                searchResults = []
                            }
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        if isLoading {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    ProgressView()
                                    Text("Searching...")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.5))
                                }
                                Spacer()
                            }
                            .padding(.top, 60)
                        } else if !searchResults.isEmpty {
                            // Search Results
                            Text("Results")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 4)
                            
                            ForEach(searchResults) { product in
                                FoodSuggestionRow(
                                    name: product.displayName,
                                    calories: product.nutriments?.energy_kcal_100g.map { "\(Int($0)) cal" } ?? "-- cal",
                                    servingInfo: "100g",
                                    action: {
                                        selectedProduct = product
                                        showProductDetail = true
                                    }
                                )
                            }
                        } else {
                            // Suggestions
                            Text("Suggestions")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 4)
                            
                            ForEach(suggestions, id: \.0) { suggestion in
                                FoodSuggestionRow(
                                    name: suggestion.0,
                                    calories: suggestion.1,
                                    servingInfo: suggestion.2,
                                    action: {
                                        searchText = suggestion.0
                                        performSearch()
                                    }
                                )
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showProductDetail) {
            if let product = selectedProduct {
                OFFProductDetailView(product: product, isPresented: $showProductDetail)
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let results = try await OpenFoodFactsService.shared.searchProducts(query: searchText)
                await MainActor.run {
                    self.searchResults = results
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Search error: \(error)")
                }
            }
        }
    }
}

// MARK: - Food Suggestion Row
struct FoodSuggestionRow: View {
    let name: String
    let calories: String
    let servingInfo: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Droplet icon - aligned to top
                Image(systemName: "drop.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.black.opacity(0.3))
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 6) {
                        Text(calories)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                        
                        Text("·")
                            .foregroundColor(Color.black.opacity(0.3))
                        
                        Text(servingInfo)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Plus button - aligned to center
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - OpenFoodFacts Product Detail View
struct OFFProductDetailView: View {
    let product: OFFProduct
    @Binding var isPresented: Bool
    @State private var servingAmount: Double = 1.0
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.20, green: 0.22, blue: 0.28),
                    Color(red: 0.25, green: 0.27, blue: 0.32)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("Nutrition")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Product image
                        if let imageUrl = product.image_url, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } placeholder: {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                    
                                    ProgressView()
                                }
                            }
                            .padding(.top, 20)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 20)
                        }
                        
                        // Product name
                        VStack(spacing: 8) {
                            Text(product.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            if !product.displayBrand.isEmpty {
                                Text(product.displayBrand)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // Serving size info
                        if let servingSize = product.serving_size {
                            Text("Serving: \(servingSize)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(20)
                        }
                        
                        // Nutrition info (per 100g)
                        if let nutriments = product.nutriments {
                            VStack(spacing: 16) {
                                // Calories
                                if let calories = nutriments.energy_kcal_100g {
                                    HStack(spacing: 8) {
                                        Text("🔥")
                                            .font(.system(size: 20))
                                        
                                        Text("Calories")
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(.white.opacity(0.8))
                                        
                                        Spacer()
                                        
                                        Text("\(Int(calories))")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text("/ 100g")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding(.horizontal, 24)
                                }
                                
                                // Macros
                                HStack(spacing: 20) {
                                    if let protein = nutriments.proteins_100g {
                                        MacroItem(
                                            icon: "🍗",
                                            label: "Protein",
                                            value: String(format: "%.1fg", protein),
                                            color: Color(red: 0.89, green: 0.85, blue: 0.88)
                                        )
                                    }
                                    
                                    if let carbs = nutriments.carbohydrates_100g {
                                        MacroItem(
                                            icon: "🌾",
                                            label: "Carbs",
                                            value: String(format: "%.1fg", carbs),
                                            color: Color(red: 0.96, green: 0.93, blue: 0.87)
                                        )
                                    }
                                    
                                    if let fat = nutriments.fat_100g {
                                        MacroItem(
                                            icon: "💧",
                                            label: "Fats",
                                            value: String(format: "%.1fg", fat),
                                            color: Color(red: 0.87, green: 0.90, blue: 0.95)
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                                
                                // Additional nutrients
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal, 24)
                                
                                HStack(spacing: 20) {
                                    if let fiber = nutriments.fiber_100g {
                                        NutrientItem(
                                            icon: "🥦",
                                            label: "Fiber",
                                            value: String(format: "%.1fg", fiber),
                                            color: Color.purple.opacity(0.3)
                                        )
                                    }
                                    
                                    if let sugar = nutriments.sugars_100g {
                                        NutrientItem(
                                            icon: "🍬",
                                            label: "Sugar",
                                            value: String(format: "%.1fg", sugar),
                                            color: Color.pink.opacity(0.3)
                                        )
                                    }
                                    
                                    if let sodium = nutriments.sodium_100g {
                                        NutrientItem(
                                            icon: "🧂",
                                            label: "Sodium",
                                            value: String(format: "%.0fmg", sodium * 1000),
                                            color: Color.orange.opacity(0.3)
                                        )
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom button
                Button(action: {
                    // Add to diary functionality here
                    isPresented = false
                }) {
                    Text("Add to Diary")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.20))
                        .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    ContentView()
}

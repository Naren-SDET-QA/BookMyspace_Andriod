package com.bookmyspace.bookmyspace.ui.screens

import android.widget.Toast
import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil.compose.AsyncImage
import com.bookmyspace.bookmyspace.data.model.*
import com.bookmyspace.bookmyspace.data.repository.BookMySpaceRepository
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InstituteOwnerDashboardScreen(
    onNavigateBack: () -> Unit,
    onNavigateToLogin: () -> Unit = {},
    onNavigateToDiscovery: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val authUser by BookMySpaceRepository.authUser.collectAsState()
    val institutes by BookMySpaceRepository.institutes.collectAsState()
    val classes by BookMySpaceRepository.instituteClasses.collectAsState()

    var selectedTab by remember { mutableIntStateOf(1) } // 0: Overview, 1: Batches/Classes, 2: Faculty, 3: Institute Profile, 4: Inquiries
    var editingClass by remember { mutableStateOf<InstituteClass?>(null) }
    var isAddingNewClass by remember { mutableStateOf(false) }

    var editingFaculty by remember { mutableStateOf<FacultyMember?>(null) }
    var isAddingNewFaculty by remember { mutableStateOf(false) }

    var isEditingInstituteProfile by remember { mutableStateOf(false) }
    var classToDelete by remember { mutableStateOf<InstituteClass?>(null) }

    val myInstitute = remember(institutes, authUser) {
        institutes.firstOrNull() ?: InstituteProfile(
            id = "inst_smash_pro",
            name = "Pullela Champions Badminton Academy",
            tagline = "Professional Sports Coaching & Training Academy",
            category = "Sports & Fitness",
            city = "Hyderabad"
        )
    }

    val myClasses = remember(classes, myInstitute) {
        classes.filter { it.instituteId == myInstitute.id || myInstitute.id.isBlank() }
    }

    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Institute Owner Portal", fontWeight = FontWeight.Bold, fontSize = 18.sp)
                            Spacer(modifier = Modifier.width(6.dp))
                            Surface(
                                color = MaterialTheme.colorScheme.primaryContainer,
                                shape = RoundedCornerShape(6.dp)
                            ) {
                                Text(
                                    "OWNER",
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Black,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text(
                            myInstitute.name,
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = {
                        isEditingInstituteProfile = true
                    }) {
                        Icon(Icons.Default.Edit, contentDescription = "Edit Profile")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = {
                    when (selectedTab) {
                        1 -> isAddingNewClass = true
                        2 -> isAddingNewFaculty = true
                        else -> isAddingNewClass = true
                    }
                },
                icon = { Icon(Icons.Default.Add, contentDescription = null) },
                text = {
                    Text(
                        when (selectedTab) {
                            1 -> "New Batch"
                            2 -> "Add Faculty"
                            else -> "New Batch"
                        },
                        fontWeight = FontWeight.Bold
                    )
                },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            )
        },
        modifier = modifier.testTag("institute_owner_dashboard_screen")
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Live Preview Banner for Owner
            Surface(
                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.45f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f)
                    ) {
                        Icon(
                            Icons.Default.TouchApp,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            "Instant Plug & Play: Edits go live to students immediately!",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    Button(
                        onClick = onNavigateBack,
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                    ) {
                        Icon(Icons.Default.Visibility, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("View App", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                    }
                }
            }

            ScrollableTabRow(
                selectedTabIndex = selectedTab,
                edgePadding = 16.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Overview 📊", fontSize = 13.sp, fontWeight = FontWeight.Bold) }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("Batches & Timings (${myClasses.size}) ⏰", fontSize = 13.sp, fontWeight = FontWeight.Bold) }
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = { Text("Faculty (${myInstitute.facultyMembers.size}) 👨‍🏫", fontSize = 13.sp, fontWeight = FontWeight.Bold) }
                )
                Tab(
                    selected = selectedTab == 3,
                    onClick = { selectedTab = 3 },
                    text = { Text("Institute Profile 🏛️", fontSize = 13.sp, fontWeight = FontWeight.Bold) }
                )
                Tab(
                    selected = selectedTab == 4,
                    onClick = { selectedTab = 4 },
                    text = { Text("Inquiries (3) 💬", fontSize = 13.sp, fontWeight = FontWeight.Bold) }
                )
            }

            when (selectedTab) {
                0 -> OwnerInstituteOverviewTab(
                    institute = myInstitute,
                    classes = myClasses,
                    onAddNewBatch = { isAddingNewClass = true },
                    onEditProfile = { isEditingInstituteProfile = true }
                )
                1 -> OwnerBatchesManagementTab(
                    classes = myClasses,
                    onEditClass = { editingClass = it },
                    onDeleteClass = { classToDelete = it },
                    onToggleLive = { cls ->
                        BookMySpaceRepository.updateClass(cls.copy(isTodayOngoing = !cls.isTodayOngoing))
                        Toast.makeText(context, "Updated live status for ${cls.title}", Toast.LENGTH_SHORT).show()
                    },
                    onToggleNewBatch = { cls ->
                        BookMySpaceRepository.updateClass(cls.copy(isNewBatch = !cls.isNewBatch, batchType = if (!cls.isNewBatch) "🔥 NEW BATCH" else "Regular"))
                        Toast.makeText(context, "Toggled New Batch tag", Toast.LENGTH_SHORT).show()
                    },
                    onToggleUpcoming = { cls ->
                        BookMySpaceRepository.updateClass(cls.copy(isUpcomingBatch = !cls.isUpcomingBatch, batchType = if (!cls.isUpcomingBatch) "🚀 UPCOMING BATCH" else "Regular"))
                        Toast.makeText(context, "Toggled Upcoming Batch tag", Toast.LENGTH_SHORT).show()
                    }
                )
                2 -> OwnerFacultyManagementTab(
                    institute = myInstitute,
                    onAddFaculty = { isAddingNewFaculty = true },
                    onEditFaculty = { editingFaculty = it },
                    onDeleteFaculty = { fac ->
                        BookMySpaceRepository.deleteFacultyFromInstitute(myInstitute.id, fac.id)
                        Toast.makeText(context, "Faculty removed", Toast.LENGTH_SHORT).show()
                    }
                )
                3 -> OwnerInstituteProfileTab(
                    institute = myInstitute,
                    onEditProfile = { isEditingInstituteProfile = true }
                )
                4 -> InstituteInquiriesTab()
            }
        }
    }

    // Dialogs for Editing/Adding Classes
    if (isAddingNewClass) {
        ClassEditOrAddDialog(
            institute = myInstitute,
            initialClass = null,
            onDismiss = { isAddingNewClass = false },
            onSave = { newClass ->
                BookMySpaceRepository.addClass(newClass)
                isAddingNewClass = false
                Toast.makeText(context, "✅ New Batch '${newClass.title}' Published!", Toast.LENGTH_SHORT).show()
            }
        )
    }

    editingClass?.let { cls ->
        ClassEditOrAddDialog(
            institute = myInstitute,
            initialClass = cls,
            onDismiss = { editingClass = null },
            onSave = { updatedClass ->
                BookMySpaceRepository.updateClass(updatedClass)
                editingClass = null
                Toast.makeText(context, "✅ Batch '${updatedClass.title}' Updated!", Toast.LENGTH_SHORT).show()
            }
        )
    }

    // Delete Confirmation Dialog
    classToDelete?.let { cls ->
        AlertDialog(
            onDismissRequest = { classToDelete = null },
            title = { Text("Delete Batch?", fontWeight = FontWeight.Bold) },
            text = { Text("Are you sure you want to remove '${cls.title}'? This action cannot be undone.") },
            confirmButton = {
                Button(
                    onClick = {
                        BookMySpaceRepository.deleteClass(cls.id)
                        classToDelete = null
                        Toast.makeText(context, "Batch deleted", Toast.LENGTH_SHORT).show()
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { classToDelete = null }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Faculty Add/Edit Dialog
    if (isAddingNewFaculty) {
        FacultyEditOrAddDialog(
            initialFaculty = null,
            onDismiss = { isAddingNewFaculty = false },
            onSave = { newFaculty ->
                BookMySpaceRepository.addFacultyToInstitute(myInstitute.id, newFaculty)
                isAddingNewFaculty = false
                Toast.makeText(context, "✅ Faculty '${newFaculty.name}' Added!", Toast.LENGTH_SHORT).show()
            }
        )
    }

    editingFaculty?.let { fac ->
        FacultyEditOrAddDialog(
            initialFaculty = fac,
            onDismiss = { editingFaculty = null },
            onSave = { updatedFaculty ->
                BookMySpaceRepository.updateFacultyInInstitute(myInstitute.id, updatedFaculty)
                editingFaculty = null
                Toast.makeText(context, "✅ Faculty '${updatedFaculty.name}' Updated!", Toast.LENGTH_SHORT).show()
            }
        )
    }

    // Institute Profile Edit Dialog
    if (isEditingInstituteProfile) {
        InstituteProfileEditDialog(
            initialInstitute = myInstitute,
            onDismiss = { isEditingInstituteProfile = false },
            onSave = { updatedInst ->
                BookMySpaceRepository.updateInstitute(updatedInst)
                isEditingInstituteProfile = false
                Toast.makeText(context, "✅ Institute Profile Updated!", Toast.LENGTH_SHORT).show()
            }
        )
    }
}

// -------------------------------------------------------------
// 1. Owner Overview Tab
// -------------------------------------------------------------
@Composable
private fun OwnerInstituteOverviewTab(
    institute: InstituteProfile,
    classes: List<InstituteClass>,
    onAddNewBatch: () -> Unit,
    onEditProfile: () -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Card(
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Institute Performance 📈", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                            Text("Realtime student inquiries & active batch slots", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        IconButton(onClick = onEditProfile) {
                            Icon(Icons.Default.Edit, contentDescription = "Edit Institute")
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceAround
                    ) {
                        OwnerStatBox(label = "Active Batches", value = "${classes.size}", icon = Icons.Default.Schedule)
                        OwnerStatBox(label = "Faculty", value = "${institute.facultyMembers.size}", icon = Icons.Default.School)
                        OwnerStatBox(label = "Rating", value = "⭐ ${institute.rating}", icon = Icons.Default.Star)
                        OwnerStatBox(label = "Inquiries", value = "18", icon = Icons.AutoMirrored.Filled.Chat)
                    }
                }
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Batch Quick-Management", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Button(
                    onClick = onAddNewBatch,
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Add Batch", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        items(classes) { cls ->
            Card(
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Faculty Photo or Avatar
                    if (cls.facultyPhotoUrl.isNotBlank()) {
                        AsyncImage(
                            model = cls.facultyPhotoUrl,
                            contentDescription = cls.facultyName,
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primaryContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Default.Person, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        }
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(cls.title, fontWeight = FontWeight.Bold, fontSize = 14.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        }
                        Text(
                            "⏰ ${cls.startTime} - ${cls.endTime} • ${cls.durationText}",
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Text(
                            "👨‍🏫 ${cls.facultyName} (${cls.facultyExperienceYears}+ Yrs Exp) • ₹${cls.feeAmount.toInt()}/${cls.feeBillingCycle}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Surface(
                        color = if (cls.isNewBatch) MaterialTheme.colorScheme.errorContainer else if (cls.isUpcomingBatch) MaterialTheme.colorScheme.tertiaryContainer else MaterialTheme.colorScheme.secondaryContainer,
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            if (cls.isNewBatch) "NEW" else if (cls.isUpcomingBatch) "UPCOMING" else "ACTIVE",
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 3.dp)
                        )
                    }
                }
            }
        }
    }
}

// -------------------------------------------------------------
// 2. Batches Management Tab with Full Field Editing & Highlights
// -------------------------------------------------------------
@Composable
private fun OwnerBatchesManagementTab(
    classes: List<InstituteClass>,
    onEditClass: (InstituteClass) -> Unit,
    onDeleteClass: (InstituteClass) -> Unit,
    onToggleLive: (InstituteClass) -> Unit,
    onToggleNewBatch: (InstituteClass) -> Unit,
    onToggleUpcoming: (InstituteClass) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Surface(
                color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.4f),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Default.Info, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        "Click 'Edit' on any card to update Faculty Photo, Start/End Timings, New/Upcoming batch tags, Duration, and Fees in real-time.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        items(classes, key = { it.id }) { cls ->
            OwnerBatchCard(
                classItem = cls,
                onEdit = { onEditClass(cls) },
                onDelete = { onDeleteClass(cls) },
                onToggleLive = { onToggleLive(cls) },
                onToggleNewBatch = { onToggleNewBatch(cls) },
                onToggleUpcoming = { onToggleUpcoming(cls) }
            )
        }
    }
}

@Composable
private fun OwnerBatchCard(
    classItem: InstituteClass,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    onToggleLive: () -> Unit,
    onToggleNewBatch: () -> Unit,
    onToggleUpcoming: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            // Header Row with Badges
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (classItem.isNewBatch) {
                        Surface(
                            color = MaterialTheme.colorScheme.error,
                            shape = RoundedCornerShape(6.dp)
                        ) {
                            Text(
                                "🔥 NEW BATCH",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onError,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                    if (classItem.isUpcomingBatch) {
                        Surface(
                            color = MaterialTheme.colorScheme.tertiary,
                            shape = RoundedCornerShape(6.dp)
                        ) {
                            Text(
                                "🚀 UPCOMING",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.ExtraBold,
                                color = MaterialTheme.colorScheme.onTertiary,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = RoundedCornerShape(6.dp)
                    ) {
                        Text(
                            classItem.deliveryMode.label.uppercase(),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }

                Row {
                    IconButton(onClick = onEdit, modifier = Modifier.size(32.dp)) {
                        Icon(Icons.Default.Edit, contentDescription = "Edit", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                    }
                    IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
                        Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Class Title
            Text(
                classItem.title,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
                color = MaterialTheme.colorScheme.onSurface
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Highlighted Timing & Schedule Bar
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Schedule,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        "TIMING: ",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        "${classItem.startTime} - ${classItem.endTime}",
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        "• ⏳ ${classItem.durationText}",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Faculty Details Row with Photo
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                if (classItem.facultyPhotoUrl.isNotBlank()) {
                    AsyncImage(
                        model = classItem.facultyPhotoUrl,
                        contentDescription = classItem.facultyName,
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .border(1.5.dp, MaterialTheme.colorScheme.primary, CircleShape),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            classItem.facultyName.take(1).ifBlank { "F" },
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }

                Spacer(modifier = Modifier.width(10.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        classItem.facultyName.ifBlank { "Unassigned Faculty" },
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp
                    )
                    Text(
                        "${classItem.facultyDesignation} • ⭐ ${classItem.facultyExperienceYears}+ Yrs Exp",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                // Cost Tag
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        "₹${classItem.feeAmount.toInt()}",
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 16.sp,
                        color = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        "/${classItem.feeBillingCycle}",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Fast Toggle Buttons for Owner
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChip(
                    selected = classItem.isNewBatch,
                    onClick = onToggleNewBatch,
                    label = { Text("🔥 New Batch", fontSize = 11.sp) },
                    leadingIcon = {
                        if (classItem.isNewBatch) Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(12.dp))
                    }
                )
                FilterChip(
                    selected = classItem.isUpcomingBatch,
                    onClick = onToggleUpcoming,
                    label = { Text("🚀 Upcoming", fontSize = 11.sp) },
                    leadingIcon = {
                        if (classItem.isUpcomingBatch) Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(12.dp))
                    }
                )
                FilterChip(
                    selected = classItem.isTodayOngoing,
                    onClick = onToggleLive,
                    label = { Text("🟢 Live Today", fontSize = 11.sp) },
                    leadingIcon = {
                        if (classItem.isTodayOngoing) Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(12.dp))
                    }
                )
            }
        }
    }
}

// -------------------------------------------------------------
// 3. Faculty Management Tab
// -------------------------------------------------------------
@Composable
private fun OwnerFacultyManagementTab(
    institute: InstituteProfile,
    onAddFaculty: () -> Unit,
    onEditFaculty: (FacultyMember) -> Unit,
    onDeleteFaculty: (FacultyMember) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Faculty Members & Instructors", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Button(
                    onClick = onAddFaculty,
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Add Faculty", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        items(institute.facultyMembers) { faculty ->
            Card(
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (faculty.photoUrl.isNotBlank()) {
                        AsyncImage(
                            model = faculty.photoUrl,
                            contentDescription = faculty.name,
                            modifier = Modifier
                                .size(54.dp)
                                .clip(CircleShape),
                            contentScale = ContentScale.Crop
                        )
                    } else {
                        Box(
                            modifier = Modifier
                                .size(54.dp)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.primaryContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(faculty.name.take(1), fontWeight = FontWeight.Bold, fontSize = 20.sp, color = MaterialTheme.colorScheme.primary)
                        }
                    }

                    Spacer(modifier = Modifier.width(14.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(faculty.name, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(faculty.designation.ifBlank { faculty.qualification }, fontSize = 12.sp, color = MaterialTheme.colorScheme.primary)
                        Text("⭐ ${faculty.experienceYears}+ Yrs Experience", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        if (faculty.specialties.isNotEmpty()) {
                            Text("Specialties: ${faculty.specialties.joinToString(", ")}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    Column {
                        IconButton(onClick = { onEditFaculty(faculty) }, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Default.Edit, contentDescription = "Edit", tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                        }
                        IconButton(onClick = { onDeleteFaculty(faculty) }, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Default.Delete, contentDescription = "Delete", tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                        }
                    }
                }
            }
        }
    }
}

// -------------------------------------------------------------
// 4. Institute Profile Tab
// -------------------------------------------------------------
@Composable
private fun OwnerInstituteProfileTab(
    institute: InstituteProfile,
    onEditProfile: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                if (institute.coverImageUrl.isNotBlank()) {
                    AsyncImage(
                        model = institute.coverImageUrl,
                        contentDescription = institute.name,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(140.dp)
                            .clip(RoundedCornerShape(12.dp)),
                        contentScale = ContentScale.Crop
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(institute.name, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text(institute.tagline, fontSize = 12.sp, color = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = onEditProfile) {
                        Icon(Icons.Default.Edit, contentDescription = "Edit")
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))
                Text(institute.description, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(12.dp))

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.LocationOn, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("${institute.address}, ${institute.city}", fontSize = 12.sp)
                }
                Spacer(modifier = Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Phone, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(institute.phone, fontSize = 12.sp)
                }
            }
        }

        Button(
            onClick = onEditProfile,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Icon(Icons.Default.Edit, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("Edit Institute Profile Details", fontWeight = FontWeight.Bold)
        }
    }
}

// -------------------------------------------------------------
// 5. Inquiries Tab
// -------------------------------------------------------------
@Composable
private fun InstituteInquiriesTab() {
    val sampleInquiries = listOf(
        Triple("Rajesh Sharma", "+91 94401 23456", "Interested in: Junior Elite Badminton Performance Batch (06:00 AM)"),
        Triple("Kavita Rao", "+91 98801 87654", "Inquiry for: IIT-JEE Advanced Physics Evening Batch. Is demo class available?"),
        Triple("Sunil Reddy", "+91 99012 34567", "Requesting enrollment for Full-Stack & Generative AI Bootcamp.")
    )

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Student & Parent Inquiries", fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }
        items(sampleInquiries) { (name, phone, message) ->
            Card(
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(name, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Text(phone, fontSize = 11.sp, color = MaterialTheme.colorScheme.primary)
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(message, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

// -------------------------------------------------------------
// 6. Comprehensive Class Edit / Add Modal Dialog
// -------------------------------------------------------------
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClassEditOrAddDialog(
    institute: InstituteProfile,
    initialClass: InstituteClass?,
    onDismiss: () -> Unit,
    onSave: (InstituteClass) -> Unit
) {
    val isEdit = initialClass != null

    var title by remember { mutableStateOf(initialClass?.title ?: "") }
    var category by remember { mutableStateOf(initialClass?.category ?: "Sports & Fitness") }
    var subject by remember { mutableStateOf(initialClass?.subject ?: "") }
    var description by remember { mutableStateOf(initialClass?.description ?: "") }

    // Faculty
    var facultyName by remember { mutableStateOf(initialClass?.facultyName ?: institute.facultyMembers.firstOrNull()?.name ?: "") }
    var facultyDesignation by remember { mutableStateOf(initialClass?.facultyDesignation ?: "Senior Faculty") }
    var facultyQualification by remember { mutableStateOf(initialClass?.facultyQualification ?: "Certified Specialist") }
    var facultyExpYears by remember { mutableStateOf(initialClass?.facultyExperienceYears?.toString() ?: "10") }
    var facultyPhotoUrl by remember { mutableStateOf(initialClass?.facultyPhotoUrl ?: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d") }

    // Timing & Schedule
    var startTime by remember { mutableStateOf(initialClass?.startTime ?: "06:00 AM") }
    var endTime by remember { mutableStateOf(initialClass?.endTime ?: "07:30 AM") }
    var durationText by remember { mutableStateOf(initialClass?.durationText ?: "3 Months") }
    var batchStartDate by remember { mutableStateOf(initialClass?.batchStartDate ?: "Starts This Monday") }

    // Flags
    var isNewBatch by remember { mutableStateOf(initialClass?.isNewBatch ?: true) }
    var isUpcomingBatch by remember { mutableStateOf(initialClass?.isUpcomingBatch ?: false) }
    var isTodayOngoing by remember { mutableStateOf(initialClass?.isTodayOngoing ?: false) }

    // Cost & Modality
    var feeAmount by remember { mutableStateOf(initialClass?.feeAmount?.toInt()?.toString() ?: "3500") }
    var courseFee by remember { mutableStateOf(initialClass?.courseFee?.toInt()?.toString() ?: "9000") }
    var billingCycle by remember { mutableStateOf(initialClass?.feeBillingCycle ?: "month") }
    var deliveryMode by remember { mutableStateOf(initialClass?.deliveryMode ?: ClassDeliveryMode.OFFLINE) }

    var location by remember { mutableStateOf(initialClass?.location ?: institute.address) }
    var totalSeats by remember { mutableStateOf(initialClass?.totalSeats?.toString() ?: "20") }
    var availableSeats by remember { mutableStateOf(initialClass?.availableSeats?.toString() ?: "12") }

    val facultyAvatarPresets = listOf(
        "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d" to "Male Coach 1",
        "https://images.unsplash.com/photo-1500648767791-00dcc994a43e" to "Male Senior 2",
        "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7" to "Tech Faculty 3",
        "https://images.unsplash.com/photo-1573496359142-b8d87734a5a2" to "Female Specialist 1",
        "https://images.unsplash.com/photo-1580489944761-15a19d654956" to "Dance Guru 2",
        "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d" to "Music Mentor 3"
    )

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier
                .fillMaxWidth(0.95f)
                .fillMaxHeight(0.92f),
            shape = RoundedCornerShape(20.dp),
            color = MaterialTheme.colorScheme.surface
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // Dialog Top Header
                Surface(
                    color = MaterialTheme.colorScheme.primaryContainer,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                if (isEdit) "Edit Batch Details ✏️" else "Create New Batch ✨",
                                fontWeight = FontWeight.Bold,
                                fontSize = 17.sp,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Text(
                                "Easily update faculty, timings, duration, cost & batch status",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f)
                            )
                        }
                        IconButton(onClick = onDismiss) {
                            Icon(Icons.Default.Close, contentDescription = "Close")
                        }
                    }
                }

                // Scrollable Form Body
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 16.dp, vertical = 12.dp)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // Section 1: Basic Info
                    Text("1. Batch Basic Info", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        label = { Text("Batch Title (e.g. Junior Elite Performance Batch)") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = category,
                            onValueChange = { category = it },
                            label = { Text("Category") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = subject,
                            onValueChange = { subject = it },
                            label = { Text("Subject/Topic") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                    }

                    OutlinedTextField(
                        value = description,
                        onValueChange = { description = it },
                        label = { Text("Batch Overview & Highlights") },
                        modifier = Modifier.fillMaxWidth(),
                        maxLines = 3
                    )

                    HorizontalDivider()

                    // Section 2: Timing & Batch Highlights
                    Text("2. Timing Slots, Duration & Batch Tag", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = startTime,
                            onValueChange = { startTime = it },
                            label = { Text("Start Time (e.g. 06:00 AM)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = endTime,
                            onValueChange = { endTime = it },
                            label = { Text("End Time (e.g. 07:30 AM)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                    }

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = durationText,
                            onValueChange = { durationText = it },
                            label = { Text("Duration (e.g. 3 Months, 45 Days)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = batchStartDate,
                            onValueChange = { batchStartDate = it },
                            label = { Text("Batch Start Date") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                    }

                    // Batch Flags
                    Text("Highlight Tags:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        FilterChip(
                            selected = isNewBatch,
                            onClick = { isNewBatch = !isNewBatch },
                            label = { Text("🔥 New Batch") }
                        )
                        FilterChip(
                            selected = isUpcomingBatch,
                            onClick = { isUpcomingBatch = !isUpcomingBatch },
                            label = { Text("🚀 Upcoming") }
                        )
                        FilterChip(
                            selected = isTodayOngoing,
                            onClick = { isTodayOngoing = !isTodayOngoing },
                            label = { Text("🟢 Live Today") }
                        )
                    }

                    HorizontalDivider()

                    // Section 3: Faculty Details & Photo
                    Text("3. Faculty Information & Photo", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                    OutlinedTextField(
                        value = facultyName,
                        onValueChange = { facultyName = it },
                        label = { Text("Faculty Name") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = facultyDesignation,
                            onValueChange = { facultyDesignation = it },
                            label = { Text("Designation") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = facultyExpYears,
                            onValueChange = { facultyExpYears = it },
                            label = { Text("Years Exp") },
                            modifier = Modifier.weight(0.7f),
                            singleLine = true
                        )
                    }

                    OutlinedTextField(
                        value = facultyQualification,
                        onValueChange = { facultyQualification = it },
                        label = { Text("Qualification & Accreditations") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    // Faculty Photo Presets
                    Text("Faculty Photo Preset Avatars (1-Tap Select):", fontSize = 11.sp, fontWeight = FontWeight.Medium)
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        items(facultyAvatarPresets) { (url, label) ->
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier
                                    .clickable { facultyPhotoUrl = url }
                                    .padding(2.dp)
                            ) {
                                AsyncImage(
                                    model = url,
                                    contentDescription = label,
                                    modifier = Modifier
                                        .size(46.dp)
                                        .clip(CircleShape)
                                        .border(
                                            width = if (facultyPhotoUrl == url) 2.5.dp else 1.dp,
                                            color = if (facultyPhotoUrl == url) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.4f),
                                            shape = CircleShape
                                        ),
                                    contentScale = ContentScale.Crop
                                )
                                Text(label, fontSize = 9.sp, maxLines = 1)
                            }
                        }
                    }

                    OutlinedTextField(
                        value = facultyPhotoUrl,
                        onValueChange = { facultyPhotoUrl = it },
                        label = { Text("Or Enter Custom Faculty Photo URL") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )

                    HorizontalDivider()

                    // Section 4: Cost, Seats & Delivery Mode
                    Text("4. Cost, Seats & Modality", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = MaterialTheme.colorScheme.primary)

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = feeAmount,
                            onValueChange = { feeAmount = it },
                            label = { Text("Monthly Fee (₹)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = courseFee,
                            onValueChange = { courseFee = it },
                            label = { Text("Full Course Fee (₹)") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                    }

                    // Modality Selector Chips
                    Text("Modality / Delivery Mode:", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        ClassDeliveryMode.entries.forEach { mode ->
                            FilterChip(
                                selected = deliveryMode == mode,
                                onClick = { deliveryMode = mode },
                                label = { Text(mode.label) }
                            )
                        }
                    }

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = availableSeats,
                            onValueChange = { availableSeats = it },
                            label = { Text("Available Seats") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                        OutlinedTextField(
                            value = totalSeats,
                            onValueChange = { totalSeats = it },
                            label = { Text("Total Capacity") },
                            modifier = Modifier.weight(1f),
                            singleLine = true
                        )
                    }

                    OutlinedTextField(
                        value = location,
                        onValueChange = { location = it },
                        label = { Text("Location / Campus Room") },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )
                }

                // Action Buttons Footer
                Surface(
                    color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.End,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextButton(onClick = onDismiss) {
                            Text("Cancel")
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Button(
                            onClick = {
                                val expYears = facultyExpYears.toIntOrNull() ?: 8
                                val fee = feeAmount.toDoubleOrNull() ?: 3000.0
                                val cFee = courseFee.toDoubleOrNull() ?: 8000.0
                                val avail = availableSeats.toIntOrNull() ?: 10
                                val tot = totalSeats.toIntOrNull() ?: 25

                                val batchTag = if (isNewBatch) "🔥 NEW BATCH" else if (isUpcomingBatch) "🚀 UPCOMING BATCH" else "Regular"

                                val finalClass = InstituteClass(
                                    id = initialClass?.id ?: "cls_${UUID.randomUUID().toString().take(8)}",
                                    instituteId = institute.id,
                                    instituteName = institute.name,
                                    title = title.ifBlank { "New Training Batch" },
                                    category = category.ifBlank { "Coaching" },
                                    subject = subject.ifBlank { title },
                                    subjectOrSpecialization = subject,
                                    description = description.ifBlank { "Comprehensive training curriculum with expert faculty." },
                                    facultyName = facultyName.ifBlank { "Senior Faculty" },
                                    facultyDesignation = facultyDesignation,
                                    facultyQualification = facultyQualification,
                                    facultyExperienceYears = expYears,
                                    facultyPhotoUrl = facultyPhotoUrl,
                                    instructorName = facultyName,
                                    coverImageUrl = initialClass?.coverImageUrl ?: institute.coverImageUrl,
                                    startTime = startTime,
                                    endTime = endTime,
                                    classTimings = "$startTime - $endTime",
                                    durationText = durationText,
                                    batchStartDate = batchStartDate,
                                    batchType = batchTag,
                                    batchHighlightTag = batchTag,
                                    isNewBatch = isNewBatch,
                                    isUpcomingBatch = isUpcomingBatch,
                                    isTodayOngoing = isTodayOngoing,
                                    deliveryMode = deliveryMode,
                                    feeAmount = fee,
                                    monthlyFee = fee,
                                    courseFee = cFee,
                                    feeBillingCycle = billingCycle,
                                    availableSeats = avail,
                                    totalSeats = tot,
                                    seatsAvailable = avail,
                                    seatsTotal = tot,
                                    location = location.ifBlank { institute.address },
                                    city = institute.city,
                                    contactPhone = institute.phone,
                                    contactWhatsapp = institute.whatsapp,
                                    isPublished = true,
                                    enrollmentOpen = true
                                )
                                onSave(finalClass)
                            },
                            shape = RoundedCornerShape(10.dp)
                        ) {
                            Icon(Icons.Default.Save, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(if (isEdit) "Save Changes" else "Publish Batch", fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }
    }
}

// -------------------------------------------------------------
// 7. Faculty Edit / Add Dialog
// -------------------------------------------------------------
@Composable
fun FacultyEditOrAddDialog(
    initialFaculty: FacultyMember?,
    onDismiss: () -> Unit,
    onSave: (FacultyMember) -> Unit
) {
    val isEdit = initialFaculty != null
    var name by remember { mutableStateOf(initialFaculty?.name ?: "") }
    var designation by remember { mutableStateOf(initialFaculty?.designation ?: "Senior Faculty") }
    var qualification by remember { mutableStateOf(initialFaculty?.qualification ?: "Certified Master Coach") }
    var experienceYears by remember { mutableStateOf(initialFaculty?.experienceYears?.toString() ?: "10") }
    var photoUrl by remember { mutableStateOf(initialFaculty?.photoUrl ?: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d") }
    var bio by remember { mutableStateOf(initialFaculty?.bio ?: "") }
    var specialtiesText by remember { mutableStateOf(initialFaculty?.specialties?.joinToString(", ") ?: "Coaching, Mentoring") }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .padding(20.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    if (isEdit) "Edit Faculty Profile" else "Add New Faculty",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp
                )

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Faculty Name") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = designation,
                    onValueChange = { designation = it },
                    label = { Text("Designation") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = qualification,
                    onValueChange = { qualification = it },
                    label = { Text("Qualification") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = experienceYears,
                    onValueChange = { experienceYears = it },
                    label = { Text("Experience in Years") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = photoUrl,
                    onValueChange = { photoUrl = it },
                    label = { Text("Photo URL") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = specialtiesText,
                    onValueChange = { specialtiesText = it },
                    label = { Text("Specialties (comma separated)") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) { Text("Cancel") }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(onClick = {
                        val finalMember = FacultyMember(
                            id = initialFaculty?.id ?: "fac_${UUID.randomUUID().toString().take(6)}",
                            name = name.ifBlank { "Faculty Member" },
                            designation = designation,
                            qualification = qualification,
                            experienceYears = experienceYears.toIntOrNull() ?: 8,
                            photoUrl = photoUrl,
                            bio = bio,
                            specialties = specialtiesText.split(",").map { it.trim() }.filter { it.isNotBlank() }
                        )
                        onSave(finalMember)
                    }) {
                        Text("Save")
                    }
                }
            }
        }
    }
}

// -------------------------------------------------------------
// 8. Institute Profile Edit Dialog
// -------------------------------------------------------------
@Composable
fun InstituteProfileEditDialog(
    initialInstitute: InstituteProfile,
    onDismiss: () -> Unit,
    onSave: (InstituteProfile) -> Unit
) {
    var name by remember { mutableStateOf(initialInstitute.name) }
    var tagline by remember { mutableStateOf(initialInstitute.tagline) }
    var description by remember { mutableStateOf(initialInstitute.description) }
    var address by remember { mutableStateOf(initialInstitute.address) }
    var phone by remember { mutableStateOf(initialInstitute.phone) }
    var whatsapp by remember { mutableStateOf(initialInstitute.whatsapp) }
    var coverUrl by remember { mutableStateOf(initialInstitute.coverImageUrl) }

    Dialog(onDismissRequest = onDismiss) {
        Card(
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier
                    .padding(20.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text("Edit Institute Profile", fontWeight = FontWeight.Bold, fontSize = 16.sp)

                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Institute Name") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = tagline,
                    onValueChange = { tagline = it },
                    label = { Text("Tagline") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Description") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )

                OutlinedTextField(
                    value = address,
                    onValueChange = { address = it },
                    label = { Text("Campus Address") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = phone,
                        onValueChange = { phone = it },
                        label = { Text("Phone") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = whatsapp,
                        onValueChange = { whatsapp = it },
                        label = { Text("WhatsApp") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                }

                OutlinedTextField(
                    value = coverUrl,
                    onValueChange = { coverUrl = it },
                    label = { Text("Cover Image URL") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) { Text("Cancel") }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(onClick = {
                        val updated = initialInstitute.copy(
                            name = name,
                            tagline = tagline,
                            description = description,
                            address = address,
                            phone = phone,
                            whatsapp = whatsapp,
                            coverImageUrl = coverUrl
                        )
                        onSave(updated)
                    }) {
                        Text("Save Profile")
                    }
                }
            }
        }
    }
}

@Composable
private fun OwnerStatBox(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
        Spacer(modifier = Modifier.height(4.dp))
        Text(value, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = MaterialTheme.colorScheme.onSurface)
        Text(label, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
